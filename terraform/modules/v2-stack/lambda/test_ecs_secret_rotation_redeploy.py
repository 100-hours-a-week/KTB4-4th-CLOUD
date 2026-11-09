import importlib.util
import json
import os
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock


MODULE_PATH = Path(__file__).with_name("ecs_secret_rotation_redeploy.py")


class SecretRotationRedeployTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ecs = MagicMock()
        cls.secrets_manager = MagicMock()
        cls.ssm = MagicMock()
        clients = {
            "ecs": cls.ecs,
            "secretsmanager": cls.secrets_manager,
            "ssm": cls.ssm,
        }
        sys.modules["boto3"] = SimpleNamespace(client=lambda name: clients[name])
        os.environ.update(
            {
                "CLUSTER_NAME": "needu-test-cluster",
                "BACKEND_SERVICE_NAME": "needu-test-backend",
                "AI_SERVICE_NAME": "needu-test-ai",
                "MYSQL_SECRET_ARN": "arn:mysql",
                "POSTGRES_SECRET_ARN": "arn:postgres",
                "POSTGRES_HOST": "postgres.example.com",
                "POSTGRES_PORT": "5432",
                "AI_DATABASE_URL_PARAMETER": "/needu/v2/test/ai/CATALOG_DATABASE_URL_RO",
            }
        )
        spec = importlib.util.spec_from_file_location(
            "ecs_secret_rotation_redeploy", MODULE_PATH
        )
        cls.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.module)

    def setUp(self):
        self.ecs.reset_mock()
        self.secrets_manager.reset_mock()
        self.ssm.reset_mock()
        self.ecs.update_service.return_value = {
            "service": {"deployments": [{"id": "deployment-1"}]}
        }

    def test_build_database_url_encodes_credentials_and_preserves_options(self):
        result = self.module.build_database_url(
            "postgresql://old:old@old.example.com:5432/needu_vector?ssl=require",
            "needu@user",
            "p@ss:/word",
            "postgres.example.com",
            5432,
        )

        self.assertEqual(
            result,
            "postgresql://needu%40user:p%40ss%3A%2Fword"
            "@postgres.example.com:5432/needu_vector?ssl=require",
        )

    def test_mysql_rotation_redeploys_only_backend(self):
        result = self.module.handler(
            {
                "resources": ["arn:mysql"],
                "detail": {"labelUpdated": "AWSCURRENT"},
            },
            None,
        )

        self.assertEqual(result["target"], "backend")
        self.ecs.update_service.assert_called_once_with(
            cluster="needu-test-cluster",
            service="needu-test-backend",
            forceNewDeployment=True,
        )
        self.secrets_manager.get_secret_value.assert_not_called()
        self.ssm.put_parameter.assert_not_called()

    def test_postgres_rotation_updates_parameter_before_ai_redeploy(self):
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

        self.assertEqual(result["target"], "ai")
        self.assertTrue(result["parameterUpdated"])
        self.ssm.put_parameter.assert_called_once_with(
            Name="/needu/v2/test/ai/CATALOG_DATABASE_URL_RO",
            Value=(
                "postgresql://needu:new-password"
                "@postgres.example.com:5432/needu_vector"
            ),
            Type="SecureString",
            Overwrite=True,
        )
        self.ecs.update_service.assert_called_once_with(
            cluster="needu-test-cluster",
            service="needu-test-ai",
            forceNewDeployment=True,
        )

    def test_unexpected_secret_is_ignored(self):
        result = self.module.handler(
            {
                "resources": ["arn:other"],
                "detail": {"labelUpdated": "AWSCURRENT"},
            },
            None,
        )

        self.assertFalse(result["redeployed"])
        self.ecs.update_service.assert_not_called()
        self.ssm.put_parameter.assert_not_called()


if __name__ == "__main__":
    unittest.main()
