# Migrating from v2 to v3

v3 improves the structure of TerraNext and adds a few new features. As a result, there are some breaking changes that require updates to your Terraform code.

Once you've ensured your variables match the new names, you can apply straight away if you wish, but this will cause all resources to be destroyed and recreated. If you are okay with some downtime, this is by far the simplest approach. Otherwise, please see the migration steps for assistance.

## Breaking changes

### 1. `slug` should be PascalCase

In v2, `slug` was usually a kebab-case identifier (e.g. `my-website`). In v3, it is expected to be PascalCase (e.g. `MyWebsite`) to follow AWS resource naming conventions. This means you should update your `slug` value to be PascalCase.

```hcl
# v2
slug = "my-website"

# v3
slug = "MyWebsite"
```

This changes every resource name in AWS (Lambda functions, IAM roles, S3 buckets, CloudFront distributions, SQS queues, etc.). Existing resources cannot be renamed in-place and will be destroyed and recreated.

### 2. Renamed variables

| v2                                        | v3                                       |
| ----------------------------------------- | ---------------------------------------- |
| `runtime_environment_variables`           | `server_environment_variables`           |
| `runtime_iam_execution_policy_statements` | `server_iam_execution_policy_statements` |

### 3. Changed defaults

| Variable       | v2 default                                          | v3 default |
| -------------- | --------------------------------------------------- | ---------- |
| `static_paths` | `["/llms.txt", "/llms-full.txt", "/.well-known/*"]` | `[]`       |

If you relied on the v2 default, explicitly set `static_paths` in your module call.

### 4. Module structure flattened

The `modules/assets`, `modules/cdn`, and `modules/revalidation-queue` child modules have been inlined into root-level files (`assets.tf`, `cdn.tf`, `revalidation-queue.tf`). The `modules/revalidation-seeder` module has been replaced by the generic `modules/lambda` module.

This means all resource addresses have changed. For example:

| v2 address                                                       | v3 address                                                                     |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| `module.assets.aws_s3_bucket.this`                               | `aws_s3_bucket.assets`                                                         |
| `module.assets.aws_cloudfront_origin_access_control.this`        | `aws_cloudfront_origin_access_control.assets`                                  |
| `module.cloudfront.aws_cloudfront_distribution.this`             | `aws_cloudfront_distribution.cdn`                                              |
| `module.cloudfront.aws_cloudfront_function.this`                 | `aws_cloudfront_function.host_header`                                          |
| `module.cloudfront.aws_cloudfront_cache_policy.this`             | `aws_cloudfront_cache_policy.cdn`                                              |
| `module.cloudfront.aws_s3_bucket.log`                            | `aws_s3_bucket.cdn_logs`                                                       |
| `module.cloudfront.aws_route53_record.a`                         | `aws_route53_record.cdn_a`                                                     |
| `module.cloudfront.aws_route53_record.aaaa`                      | `aws_route53_record.cdn_aaaa`                                                  |
| `module.revalidation_queue.aws_sqs_queue.this`                   | `aws_sqs_queue.revalidation`                                                   |
| `module.revalidation_queue.aws_kms_key.this`                     | `aws_kms_key.revalidation`                                                     |
| `module.revalidation_queue.aws_lambda_event_source_mapping.this` | `aws_lambda_event_source_mapping.revalidation`                                 |
| `module.revalidation_seeder.aws_lambda_function.this`            | `module.revalidation_seeder.aws_lambda_function.this` (now uses lambda module) |

### 5. New variables

v3 exposes configuration that was previously hardcoded in child modules:

- `server_memory_size` — server Lambda memory (default: `512`)
- `cdn_cors` — CORS configuration
- `cdn_hsts` — HSTS configuration
- `cdn_cache_policy` — CloudFront cache policy
- `cdn_origin_request_policy` — CloudFront origin request policy
- `cdn_custom_headers` — custom response headers
- `cdn_geo_restriction` — georestriction settings
- `cdn_remove_headers` — response header removal
- `cdn_create_invalidation_after_deployment` — automatic cache invalidation (default: `true`)
- `revalidation_queue_kms_key_arn` — bring your own KMS key for SQS
- `replication_configuration` — S3 bucket replication

No action is required for these unless you want to customize them — all have sensible defaults.

## Migration steps

### Option A: Destroy and recreate (simplest)

If downtime is acceptable, this is the easiest approach:

```bash
terraform destroy
# Update your module source to v3, update variable names
terraform apply
```

### Option B: State migration (zero downtime)

If you need to preserve resources, you must move every resource to its new address in Terraform state. Since v3 also changes resource names in AWS (due to PascalCase), even state moves will result in replacements for most resources. A full state migration is only practical if your `slug` value happens to already be PascalCase.

1. **Update your module call** with the new variable names and v3 source.

2. **Move state for each resource** that changed address. For example:

   ```bash
   # Assets
   terraform state mv 'module.terranext.module.assets.aws_s3_bucket.this' 'module.terranext.aws_s3_bucket.assets'
   terraform state mv 'module.terranext.module.assets.aws_s3_bucket_public_access_block.this' 'module.terranext.aws_s3_bucket_public_access_block.assets'
   terraform state mv 'module.terranext.module.assets.aws_s3_bucket_versioning.this' 'module.terranext.aws_s3_bucket_versioning.assets'
   terraform state mv 'module.terranext.module.assets.aws_s3_bucket_server_side_encryption_configuration.this' 'module.terranext.aws_s3_bucket_server_side_encryption_configuration.assets'
   terraform state mv 'module.terranext.module.assets.aws_s3_bucket_lifecycle_configuration.this' 'module.terranext.aws_s3_bucket_lifecycle_configuration.assets'
   terraform state mv 'module.terranext.module.assets.aws_cloudfront_origin_access_control.this' 'module.terranext.aws_cloudfront_origin_access_control.assets'

   # CDN
   terraform state mv 'module.terranext.module.cloudfront.aws_cloudfront_distribution.this' 'module.terranext.aws_cloudfront_distribution.cdn'
   terraform state mv 'module.terranext.module.cloudfront.aws_cloudfront_function.this' 'module.terranext.aws_cloudfront_function.host_header'
   terraform state mv 'module.terranext.module.cloudfront.aws_cloudfront_cache_policy.this' 'module.terranext.aws_cloudfront_cache_policy.cdn'
   terraform state mv 'module.terranext.module.cloudfront.aws_cloudfront_response_headers_policy.this' 'module.terranext.aws_cloudfront_response_headers_policy.cdn'
   terraform state mv 'module.terranext.module.cloudfront.aws_s3_bucket_policy.this' 'module.terranext.aws_s3_bucket_policy.assets'
   terraform state mv 'module.terranext.module.cloudfront.aws_s3_bucket.log' 'module.terranext.aws_s3_bucket.cdn_logs'
   terraform state mv 'module.terranext.module.cloudfront.aws_s3_bucket_lifecycle_configuration.log' 'module.terranext.aws_s3_bucket_lifecycle_configuration.cdn_logs'
   terraform state mv 'module.terranext.module.cloudfront.aws_s3_bucket_public_access_block.log' 'module.terranext.aws_s3_bucket_public_access_block.cdn_logs'
   terraform state mv 'module.terranext.module.cloudfront.data.aws_cloudfront_cache_policy.static' 'module.terranext.data.aws_cloudfront_cache_policy.static'
   terraform state mv 'module.terranext.module.cloudfront.data.aws_cloudfront_origin_request_policy.this[0]' 'module.terranext.data.aws_cloudfront_origin_request_policy.cdn[0]'

   # Revalidation Queue
   terraform state mv 'module.terranext.module.revalidation_queue.aws_sqs_queue.this' 'module.terranext.aws_sqs_queue.revalidation'
   terraform state mv 'module.terranext.module.revalidation_queue.aws_kms_key.this[0]' 'module.terranext.aws_kms_key.revalidation[0]'
   terraform state mv 'module.terranext.module.revalidation_queue.aws_lambda_event_source_mapping.this' 'module.terranext.aws_lambda_event_source_mapping.revalidation'

   # DNS (if create_dns_records = true)
   terraform state mv 'module.terranext.module.cloudfront.aws_route53_record.a["example.com"]' 'module.terranext.aws_route53_record.cdn_a["example.com"]'
   terraform state mv 'module.terranext.module.cloudfront.aws_route53_record.aaaa["example.com"]' 'module.terranext.aws_route53_record.cdn_aaaa["example.com"]'
   ```

   Replace `module.terranext` with the name you use for the TerraNext module, and `example.com` with your domain.

3. **Run `terraform plan`** and verify the changes are as expected. Resources whose AWS names changed (due to PascalCase) will still show as replacements — this is expected.

## Example: updated module call

```hcl
# v2
module "terranext" {
  source  = "TerraNext-Dev/opennext/aws"
  version = "~> 2.0"

  name                          = "My Website"
  slug                          = "my-website"
  aws_region                    = "us-east-1"
  opennext_build_path           = "../.open-next"
  deployment_domain             = "example.com"
  acm_arn                       = aws_acm_certificate.cert.arn
  hosted_zone_id                = data.aws_route53_zone.main.zone_id
  create_dns_records            = true
  runtime_environment_variables = { DATABASE_URL = "..." }
}

# v3
module "terranext" {
  source  = "TerraNext-Dev/opennext/aws"
  version = "~> 3.0"

  name                         = "My Website"
  slug                         = "MyWebsite"
  aws_region                   = "us-east-1"
  opennext_build_path          = "../.open-next"
  deployment_domain            = "example.com"
  acm_arn                      = aws_acm_certificate.cert.arn
  hosted_zone_id               = data.aws_route53_zone.main.zone_id
  create_dns_records           = true
  server_environment_variables = { DATABASE_URL = "..." }
}
```
