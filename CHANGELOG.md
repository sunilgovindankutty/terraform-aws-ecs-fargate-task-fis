# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-03-06

### Added
- Initial release of the module
- Support for enabling AWS FIS on ECS Fargate tasks
- Support for various fault injection types:
  - network-latency
  - network-packet-loss
  - network-blackhole-port
  - cpu-stress
  - memory-stress
  - io-stress
  - kill-process
- Automatic configuration of:
  - SSM agent container
  - IAM roles and permissions
  - CloudWatch logging
  - Task definition properties (PID mode, network mode)
- Validation for network mode compatibility
- Support for custom log group configuration
- Example configurations in `examples/` directory