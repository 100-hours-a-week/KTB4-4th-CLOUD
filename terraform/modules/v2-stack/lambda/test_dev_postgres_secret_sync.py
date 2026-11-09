import importlib.util
import json
import os
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock


MODULE_PATH = Path(__file__).with_name("dev_postgres_secret_sync.py")


class DevPostgresSecretSyncTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.secrets_manager = MagicMock()
        cls.ssm = MagicMock()
        clients = {
            "secretsmanager": cls.secrets_manager,
            "ssm": cls.ssm,
        }
        sys.modules["boto3"] = SimpleNamespace(client=lambda name: clients[name])
        os.environ.update(
            {
                "POSTGRES_SECRET_ARN": "arn:postgres",
                "POSTGRES_HOST": "postgres.example.com",
                "POSTGRES_PORT": "5432",
                "AI_DATABASE_URL_PARAMETER": "/needu/v2/dev/ai/CATALOG_DATABASE_URL_RO",
            }
        )
        spec = importlib.util.spec_from_file_location(
            "dev_postgres_secret_sync", MODULE_PATH
        )
        cls.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.module)

    def setUp(self):
        self.secrets_manager.reset_mock()
        self.ssm.reset_mock()

    def test_postgres_rotation_updates_parameter_without_ecs(self):
        self.secrets_manager.get_secret_value.return_value = {
            "SecretString": json.dumps(
                {"username": "needu", "password": "new-password"}
            )
        }
        self.ssm.get_parameter.return_value = {
            "Parameter": {
                "Value": "postgresql://needu:old-password@old:5432/needu_vector"
            }
        }
        self.ssm.put_parameter.return_value = {"Version": 2}

        result = self.module.handler(
            {
                "resources": ["arn:postgres"],
                "detail": {"labelUpdated": "AWSCURRENT"},
            },
            None,
        )

        self.assertTrue(result["parameterUpdated"])
        self.assertFalse(result["redeployed"])
        self.ssm.put_parameter.assert_called_once_with(
            Name="/needu/v2/dev/ai/CATALOG_DATABASE_URL_RO",
            Value=(
                "postgresql://needu:new-password"
                "@postgres.example.com:5432/needu_vector"
            ),
            Type="SecureString",
            Overwrite=True,
        )

    def test_unexpected_secret_is_ignored(self):
        result = self.module.handler(
            {
                "resources": ["arn:other"],
                "detail": {"labelUpdated": "AWSCURRENT"},
            },
            None,
        )

        self.assertFalse(result["parameterUpdated"])
        self.secrets_manager.get_secret_value.assert_not_called()
        self.ssm.put_parameter.assert_not_called()


if __name__ == "__main__":
    unittest.main()
