output "valkey_stream_primary_endpoint" {
  description = "V3 Production Streams primary endpoint"
  value       = module.valkey.primary_endpoint
}

output "valkey_stream_security_group_id" {
  value = module.valkey.security_group_id
}

output "valkey_cache_primary_endpoint" {
  description = "V3 Production Cache primary endpoint"
  value       = module.valkey_cache.primary_endpoint
}

output "valkey_cache_security_group_id" {
  value = module.valkey_cache.security_group_id
}
