# Terraform FCC
Practice project following the [Terraform Course from FeeCodeCamp](https://www.youtube.com/watch?v=SLB_c_ayRMo).
However, instead of using actual AWS resources, I've used LocalStack to emulate the AWS provider. I've also used its CLI tools `awslocal` and `tflocal` to integrate with both AWS CLI and Terraform.
The resources used are available in the LocalStack Community plan.

## Installation

The project was created and executed in Ubuntu 22.04 and made use of the following tools:

- [Docker Engine](https://docs.docker.com/engine/install/)
- [AWS CLI](https://aws.amazon.com/pt/cli/)
- [Terraform](https://developer.hashicorp.com/terraform/downloads?product_intent=terraform)
- [LocalStack CLI](https://docs.localstack.cloud/getting-started/installation/)
- [LocalStacK AWS CLI](https://docs.localstack.cloud/user-guide/integrations/aws-cli/#localstack-aws-cli-awslocal)
- [Terraform Local](https://docs.localstack.cloud/user-guide/integrations/terraform/#using-the-tflocal-script)

## Course Notes
> [!NOTE]  
> Whenever `awslocal` or `tflocal` appear, they could be replaced by `aws` and `terraform` respectively, if you're using the actual AWS.

### Provisioning
The LocalStack container must be up and running so Terraform can work with the mocked AWS provider:
```console
localstack start
```
Using the `tflocal` command handles LocalStack service endpoint configurations and accepts mocked AWS credentials.
Execute these in sequence (typing `yes` whenever prompted) to provision the infrastructure:  
```console
tflocal init
tflocal plan
tflocal apply
```

Though it supposedly creates an EC2 instance, it's just an emulated instance. LocalStack Pro would be necessary to mock real instances with containers.

### Auto-approving
Skips interactive approval:
```console
tflocal apply -auto-approve
```

### Changing infrastructure
The `main.tf` file declares what the infrastructure should have. After changes in this file, the next time `tflocal apply` is executed, it will be aware of the changes and modify the infrastructure to reflect the new configuration.

### Destroying infrastructure
This can be done either via LocalStack or Terraform.
#### LocalStack:
```console
localstack stop
```
#### Terraform:  
- Destroying the whole infrastructure:
```console
tflocal destroy
```

### Target resources
> [!WARNING]  
> This is not recommended, since the result of the plan does not represent the whole configuration.

Some actions may target specific resources instead of the whole infrastructure configuration.
Examples:
- Destroying specific resources:
```console
tflocal destroy -target <resource_name>
```
- Provisioning specific resources:
```console
tflocal apply -target <resource_name>
```

### Resources information
Listing created resources:
```console
tflocal state list
```
Listing state of a specific resource (e.g. aws_eip.one):
```console
tflocal state show <resource_name>
```

### Variables
See `main.tf` for examples and usage (in comments).
