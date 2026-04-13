# Changelog

## [1.1.2](https://github.com/oliverphardman/terraform-aws-opennext/compare/v1.1.1...v1.1.2) (2026-04-13)


### Bug Fixes

* always disable server streaming ([0369a1e](https://github.com/oliverphardman/terraform-aws-opennext/commit/0369a1ed969760681dfe6815aee3b909a131f89e))

## [1.1.1](https://github.com/oliverphardman/terraform-aws-opennext/compare/v1.1.0...v1.1.1) (2026-04-13)


### Bug Fixes

* remove icons from default static paths ([004bb2b](https://github.com/oliverphardman/terraform-aws-opennext/commit/004bb2bca34fab08740feb48aad504ac5be55eb5))

## [1.1.0](https://github.com/oliverphardman/terraform-aws-opennext/compare/v1.0.2...v1.1.0) (2026-04-13)


### Features

* add VS Code settings/recommended extensions ([894781c](https://github.com/oliverphardman/terraform-aws-opennext/commit/894781c23c259259a6a292f14e92ee4058e79e6f))
* Terraform validation workflow ([ddd5dac](https://github.com/oliverphardman/terraform-aws-opennext/commit/ddd5dac66f2d148e0f60b22ba157b277119f3fe2))


### Bug Fixes

* Prettier ignore CHANGELOG ([0abaf71](https://github.com/oliverphardman/terraform-aws-opennext/commit/0abaf71d1ed2cfa1c310c2899a4cde9e7a4cc9ef))
* Release Please use GitHub app token ([aa6045d](https://github.com/oliverphardman/terraform-aws-opennext/commit/aa6045da144967d4f311a37d4cb1ca85f4830b8f))
* restore Release Please to correct release-type ([1cdc3a8](https://github.com/oliverphardman/terraform-aws-opennext/commit/1cdc3a8aba0c005ceca7b3085212a37b956ff1a8))
* run workflows on push to main ([#10](https://github.com/oliverphardman/terraform-aws-opennext/issues/10)) ([1954de8](https://github.com/oliverphardman/terraform-aws-opennext/commit/1954de89aa4a0984ed07bcb3357ee17dbb0a48bf))
* scope CodeQL workflow permissions ([#9](https://github.com/oliverphardman/terraform-aws-opennext/issues/9)) ([c8b3ddc](https://github.com/oliverphardman/terraform-aws-opennext/commit/c8b3ddcb058f971f91d6e2d37b149097cbb61410))
* terraform fmt cdn ([b082303](https://github.com/oliverphardman/terraform-aws-opennext/commit/b08230329be3e64327cf864945db97e8cbbcbbd8))

## [1.0.2](https://github.com/oliverphardman/terraform-aws-opennext/compare/v1.0.1...v1.0.2) (2026-04-13)

### Bug Fixes

- README markdown syntax ([#5](https://github.com/oliverphardman/terraform-aws-opennext/issues/5)) ([972fe0f](https://github.com/oliverphardman/terraform-aws-opennext/commit/972fe0f286e35f0f914a410ae3d5e9cca42e18a4))

## [1.0.1](https://github.com/oliverphardman/terraform-aws-opennext/compare/v1.0.0...v1.0.1) (2026-04-13)

### Bug Fixes

- module name reference ([#3](https://github.com/oliverphardman/terraform-aws-opennext/issues/3)) ([b81107f](https://github.com/oliverphardman/terraform-aws-opennext/commit/b81107f1b501cefc5c9b257d41ae036b1c3998e7))

## 1.0.0 (2026-04-13)

### Features

- add revalidation seeder mechanism ([e2a5228](https://github.com/oliverphardman/terraform-aws-opennext/commit/e2a5228e0daeeb55de73a8dae89a18dbc12408e4))
- add streaming support variable for server function ([1d53863](https://github.com/oliverphardman/terraform-aws-opennext/commit/1d538638c2053e09e530febf99a4162a3c94f36f))
- Dependabot ([b5c8c94](https://github.com/oliverphardman/terraform-aws-opennext/commit/b5c8c94caa20208c289d6cbe20d8334e9af0e639))
- GitHub Release Please ([ed64096](https://github.com/oliverphardman/terraform-aws-opennext/commit/ed64096660b5c03b4e4de3e1284f20e092ba1690))
- SECURITY.md ([ffe37f8](https://github.com/oliverphardman/terraform-aws-opennext/commit/ffe37f800581a062c59ea027636fb1e6719d44e7))
- Terranext! ([c3d4a71](https://github.com/oliverphardman/terraform-aws-opennext/commit/c3d4a7101920439ab8453bb33ba06a197927d776))
- Trivy scan ([65bd641](https://github.com/oliverphardman/terraform-aws-opennext/commit/65bd64121a98b19d6b265d4d9958b4ac8fb149fb))

### Bug Fixes

- add custom_origin_config for Lambda CloudFront origins ([22486a5](https://github.com/oliverphardman/terraform-aws-opennext/commit/22486a5067b1953cda70d800263e4f2d97aff725))
- add SQS long polling with 20-second wait ([d1532fe](https://github.com/oliverphardman/terraform-aws-opennext/commit/d1532fe88ade3d972449679bcfb4dd6efee7f10f))
- always create CloudFront x-forwarded-host function ([ae1fa3b](https://github.com/oliverphardman/terraform-aws-opennext/commit/ae1fa3b751ea91cd2102552490e70401118a3e5b))
- cache table key syntax ([39576b1](https://github.com/oliverphardman/terraform-aws-opennext/commit/39576b1ad96d10afeee0e0cdc3c4191584e0b228))
- CDN Route 53 record creation ([d736a2b](https://github.com/oliverphardman/terraform-aws-opennext/commit/d736a2b4e874bbd9227b4a1cb0435b4b58e94466))
- change cache policy cookie behaviour from all to none ([54fb365](https://github.com/oliverphardman/terraform-aws-opennext/commit/54fb3654a3056b98dfc7a8f9490371ba01ee1f90))
- CloudFront Lambda execution permissions ([86da90d](https://github.com/oliverphardman/terraform-aws-opennext/commit/86da90d0938f619807a20ff1803b6eafbb915053))
- correct S3 key prefixes to match OpenNext conventions ([0c85aeb](https://github.com/oliverphardman/terraform-aws-opennext/commit/0c85aeba6ae3dec50b8e4fb79fbd3965a05c4d67))
- correct server function S3 IAM permissions ([db214a8](https://github.com/oliverphardman/terraform-aws-opennext/commit/db214a82a208e1cd2d94c145c6c0f492c00b4dba))
- data block reference to bucket in CDN ([b132295](https://github.com/oliverphardman/terraform-aws-opennext/commit/b13229557f30b3a72a762d600da6de2d9b5a474a))
- define DynamoDB index attribute ([19f3d5e](https://github.com/oliverphardman/terraform-aws-opennext/commit/19f3d5e42ec9c034646e33791c40aa981b7ef429))
- set SQS event source batch size to 5 ([985d3e0](https://github.com/oliverphardman/terraform-aws-opennext/commit/985d3e0a8a40edca29d7b91f9069cb0777cb99ef))
- static value for creating DNS records by CloudFront ([0aac9e2](https://github.com/oliverphardman/terraform-aws-opennext/commit/0aac9e298eba9d4f1f70ed79876f0a08a36bfcd5))
- tab spacing ([3399aa3](https://github.com/oliverphardman/terraform-aws-opennext/commit/3399aa386838dc1e24b1bf01afa991bf6544166c))

### Miscellaneous Chores

- update reference to tf module in README ([2416f40](https://github.com/oliverphardman/terraform-aws-opennext/commit/2416f4055a1a24ad3aeed736745d0ea048d3bb3c))
