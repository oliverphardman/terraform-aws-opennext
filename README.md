# TerraNext

TerraNext is an opinionated Terraform module designed to make it easy for you to host your Next.js app on AWS, without breaking the bank on compute.

Simply use [Terraform](https://developer.hashicorp.com/terraform) to define any supporting infrastructure you require, such as your domain or WAF configuration, then include the TerraNext module to get started. Build your app using [OpenNext](https://opennext.js.org/) and Terraform will spin up the cloud resources you need to host it.

This module is based on the excellent work by [NHS England](https://github.com/orgs/nhsengland) on [terraform-aws-opennext](https://github.com/nhs-england-tools/terraform-aws-opennext). Their module has not been maintained for a long time, but **TerraNext supports v6 of the AWS Terraform provider**, utilizes new features in AWS services and is far simpler to use.

## Quick start
1. Build your app with OpenNext
`npx @opennextjs/aws@latest build`
2. Include the TerraNext module with the required variables.
```hcl
module "terranext" {
  source = "oliverphardman/opennext/aws"

  name               = "My Website"
  slug               = "my-website"
  aws_region         = "us-east-1"
  opennext_build_path = "../.open-next"

  deployment_domain = "example.com"
  acm_arn           = aws_acm_certificate.cert.arn
  hosted_zone_id    = data.aws_route53_zone.main.zone_id
  create_dns_records  = true
}
```

## Architecture

![OpenNext AWS default recommended architecture](https://opennext.js.org/architecture.png)

TerraNext provides full coverage of the [OpenNext recommended AWS architecture](https://opennext.js.org/aws/architecture):

| Component | Architecture layer | TerraNext |
|---|---|---|
| CloudFront CDN cache | Core | CloudFront distribution with HTTP/2 and HTTP/3, HSTS, CORS, and OAC-authenticated origins |
| Server Function | Core | ARM64 Lambda (Node.js 24.x) with Function URL. Routes `/*`, `/_next/data/*`, and `/api/*` |
| Asset Files | Core | S3 bucket with versioning, encryption, and lifecycle policies. Routes `/_next/static/*` and configurable static paths |
| Image Optimization Function | Core | ARM64 Lambda with Function URL. Routes `/_next/image*` |
| Revalidation Queue | ISR Revalidation | SQS FIFO queue with KMS encryption and content-based deduplication |
| Revalidation Function | ISR Revalidation | ARM64 Lambda triggered by SQS. Updates cache in S3 and DynamoDB |
| Cache Files | ISR Revalidation | Stored in the same S3 assets bucket under the `_cache` prefix |
| Cache Table | ISR Revalidation | DynamoDB table storing cache metadata and tag-to-path mappings, seeded at deploy time |
| Warmer Function | Warmer (optional) | ARM64 Lambda invoked every 5 minutes by EventBridge to keep the server function warm |
| Route 53 | DNS (optional) | A and AAAA alias records for your custom domain and `www` subdomain |

## Prerequisites

- [Terraform](https://www.terraform.io/) >= 1.1
- AWS provider ~> 6.2
- An [OpenNext](https://opennext.js.org/) build output directory (run `npx open-next build` in your Next.js project)
- An ACM certificate in `us-east-1` for your domain (required by CloudFront)

## Variables

### Required

| Name | Type | Description |
|------|------|-------------|
| `name` | `string` | The name of the application, used as a suffix for resources |
| `slug` | `string` | A URL-safe identifier used as a prefix for all resource names |
| `aws_region` | `string` | The AWS region to deploy to |
| `opennext_build_path` | `string` | Path to the folder containing the `.open-next` build output |
| `deployment_domain` | `string` | The deployment domain for the application |
| `acm_arn` | `string` | ARN of an ACM certificate for the CloudFront distribution |

### Optional

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `hosted_zone_id` | `string` | `null` | Route 53 hosted zone ID. When provided, A and AAAA records are created for the deployment domain |
| `waf_arn` | `string` | `null` | ARN of a WAF WebACL to associate with the CloudFront distribution |
| `runtime_environment_variables` | `map(string)` | `{}` | Additional environment variables for the server Lambda function |
| `warmer_function_enabled` | `bool` | `true` | Whether to create a warmer function to reduce cold starts |
| `use_account_regional_buckets` | `bool` | `true` | Use account-regional S3 namespace to avoid global naming conflicts |
| `static_paths` | `list(string)` | `["/favicon.ico", ...]` | Static asset paths to cache via CloudFront |
| `static_asset_cache_config` | `string` | `"public,max-age=0,..."` | Cache-Control header for static assets |
| `server_streaming` | `bool` | `false` | Enable response streaming on the server function for faster TTFB |
| `enable_www_alias` | `bool` | `true` | Create an additional `www` alias and redirect to the apex domain |

## Outputs

| Name | Description |
|------|-------------|
| `cloudfront_distribution_id` | The ID of the CloudFront distribution |
| `cloudfront_distribution_domain_name` | The domain name of the CloudFront distribution |

CloudFront automatically serves both `example.com` and `www.example.com`, redirecting `www` to the apex domain. You can disable this behaviour by setting `enable_www_alias` to `false`.

## How it works

1. You build your Next.js app with OpenNext (`npx open-next build`), which outputs Lambda-compatible bundles and static assets
2. TerraNext deploys each bundle as an ARM64 Lambda function
3. Static assets are uploaded to S3
4. CloudFront routes requests to the right origin based on path patterns:
   - `/_next/static/*`, `/static/*`, and configured static paths go to S3
   - `/_next/image` goes to the Image Optimization Lambda
   - Everything else goes to the Server Lambda (your Next.js runtime)
5. ISR revalidation requests are queued in SQS FIFO and processed by the Revalidation Lambda

## Contributing
TerraNext is quite opinionated and thus doesn't expose many variables. The aim of this project is to make it really simple for anyone to get their site on AWS without having to keep a server constantly warm, while avoiding the drawbacks of using services like Amplify which give you no control over your infrastructure.

With that said, there's always choices that won't suit everyone. We'd love to hear about those, please raise an issue! Otherwise, consider making it configurable through a variable. Contributions are very welcome!

## License

TerraNext is free software under the MIT Licence. Please note that it comes with ABSOLUTELY NO WARRANTY, to the extend permitted by applicable law. See [LICENSE](LICENSE) for details.
