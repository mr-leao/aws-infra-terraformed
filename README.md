# AWS Infrastruture Deployment
Automated AWS Infrastructure deployed using Terraform and Terragrunt

## Multi-account and multi-region archictecture design

<img src="docs\ArchitectureDiagramMultiAccounts.png" alt="drawing" width="50%"/>

### Accounts  

- Control Tower (Management Account)
  It is the initial account created when you sign up for an AWS account, and it is used for consolidated billing and AWS Control Tower service
  All other accounts are provisioned from this account using the AWS Service Catalog product called "Account Factory". The AFT product guarantee that all account follow the same security and governance configurations

  - Logging Archive (Built-in) 
    It is an account created and controlled by AWS Control Tower and it is used to store CloudTrail and AWS Config logs

  - Audit (Built-in)
    It is an account created and controlled by AWS Control Tower and it is used for auditing purposes. From this account you deploy auditing tools, and provide auditor read-access to resource from other account.

- Deployment Service
  It is the account where Terraform will be executed. In the future, the account creation process can be automated using AFT for Terraform using this account.
  https://docs.aws.amazon.com/controltower/latest/userguide/aft-getting-started.html

- Central Log Archive  
  It is used for storing VPC Flowlogs and any other log types that are not CloudTrail and AWS Config logs.

- Network Hub
  It is used for centralized egress to internet through the AWS Transit Gateway

- Shared Service account  
  It is used for workload shared among multiple accounts. For example, Public Key Infrastructure, root domain, DNS resolver, shared databases, etc
  
- Production account  
  It is used for production workloads
  
- Staging account  
  It is used for staging workloads

- Development account  
  It is used for development teams<br/><br/><br/>

## Infrastrucutre Provisioning Tools
This solution I used Terraform and Terragrunt as Infrastructure-as-Code tools to configure and automate the AWS Infrastructure deployments. Those tools are very popular among DevOps Communities therefore there is no lack of support. Other advantages are:
- Modularity or the ability to reuse code which help us to enable scabalibity.
- State management for drift detect and deployment planning<br/><br/><br/>

## Terraform modules
The `library` folder contains all modules developed so far.

## Deployment requirements

### Initial configuration - Manual process

  1.  Create distinct email addresses for each AWS account according to the Architecture Design:
      e.g.:
      -	(Control Tower account)               -> aws.main@company.com 
      -	Log archive account (Built-in)        -> aws.logarchive@company.com 
      -	Audit account (Built-in)              -> aws.audit@company.com
      -	Central log archive account (Custom)  -> aws.centrallogarchive@company.com

  2.	Sign up for an Amazon Account using the root account email address
  
  3.	Select your home region, and create a KMS key using the following parameters:  
             
        - Key type: symmetric
        
        - Advanced options
          - Key material origin: KMS<br/>
          - Regionality: Single-Region Key<br/>
        
        - Alias: *control-tower*

        - key administrative permissions
          - Key administrators
            - Roles: AWSServiceRoleForSupport, AWSServiceRoleForTrustedAdvisor*
            - Key deletion: Allow key administrators to delete this key.
            - This account
              - Roles: AWSServiceRoleForSupport, AWSServiceRoleForTrustedAdvisor*
              - Key deletion: Allow key administrators to delete this key.<br/><br/>

  4. Create a landing zone using AWS Control Tower
      - Go to the AWS Control Tower service, and click on Set up landing zone.  
      - On the Landing Zone wizard page use the following information to set it up:  
        - Home region:      *YourHomeRegion*
        -	Foundational OU:  (Leave as it is)
        - Additional OU:    Shared Service, Non-Production, and Production
        -	Log archive account  
          -	Create account: %email_address%  
          -	Change account name: "Control Tower Logging"
        -	Audit account: (Leave as it is)
        -	KMS Encryption:  
          -	Check “Enable and customize encryption settings”  
          -	Select the KMS key created on the previous step called *control-tower*
      - Enable sharing with AWS Organizations
         - Go to ASW RAM (Resource Access Manager) > Settings and click on "Enable sharing with AWS Organizations"
            https://docs.aws.amazon.com/ram/latest/userguide/getting-started-sharing.html<br/><br/>
  
  5.	AWS Key Pairs

        - Create a RSA key pair for each region in each account using the following pattern from the terragrunt
          - Pattern -> `${local.vars.deployment_prefix}${local.vars.vpc_cidr_2nd_octet}-${local.vars.region}`  
          - Keypair name example -> "mgmt0-ca-central-1"

        - Save the private keys in a password manager. It will be useful if you need to create shared EC2 instances and their access is not controlled by a directory service. If the keypair is not created or it does not follow the patter, the VPC Core will execution will fail and you will see the error "no matching EC2 Key Pair found".<br/><br/>

  6. Create additional accounts using AWS Service Catalog
        a. Go to "Products", select "AWS Control Tower Account Factory", and click on the "Launch Product" button.
        b. Create all additinal accounts according to the multi-account design describe at the begging of this document
          e.g: Deployment Service, Shared Services, etc..<br/><br/>
  
  7. IAM Roles for automated deployment

      There is a Python script called `setDeploymentServiceAccessControl.py`, in the `utilities` folder, created to help you configured the IAM roles for all accounts. Before you execute the script you must have the following configurations in place:

      - Create one IAM user for each account or use existent ones that have at least "IAMFullAccess" permission to create IAM roles.  
      - Update the configuration file `accounts.json` in the `utilities` folders. It must contains valid account numbers and local profile names whose profile configuration contains access and secret keys that are not expired.  
      - The AWS credentials file `...\aws\credentials` must contains all the profiles with access and secret keys for each account.         
      - The AWS config file ...\aws\config must contains the following configuration to be able to assume the deployment service role from the deployment service account
          
          ```
          [profile MyDeploymentService]
          role_arn=arn:aws:iam::%deployment_service_account_id%:role/MyDeploymentService
          source_profile=terraform-service-user
          ```

          **In the folder `utilities\AWSCredentialsExample` you will find AWS credentials configuration**
  
  8. Steps to execute terraform deployments 

      The procedure to execute terraform tasks starts from the directory %REPO_ROOT%\deployments\

      a. Configuration -> https://www.terraform.io/cli/config/config-file
        - Install terraform and terragrunt tools, and make sure their folder location is in the system path (environment variables)
        - Create a terraform directory for:
          - Windows: "$APPDATA/terraform.d/plugin-cache" or
          - Linux: "$HOME/.terraform.d/plugin-cache"
        - Create a CLI configuration file as follows:
          - Windows: "$APPDATA/terraform.rc
          - Linux: ~/.terraformrc (Home directory)
        - Edit the CLI configuration file and include he following information:
          - Windows: plugin_cache_dir = "$APPDATA/terraform.d/plugin-cache"
          - Linux: plugin_cache_dir = "$HOME/.terraform.d/plugin-cache"
        - For terraform deployment using CICD pipeline the variable TF_PLUGIN_CACHE_DIR can be used
        
      a. Clear terragrunt cache
         On the terminal, change the directory to "deployments" folder and then execute the following command to clear the terragrunt cache. It is a good practice after you update modules from the library, so that the task will pick up the latest module version

        On Windows:  
          `get-ChildItem -Recurse -Include .terragrunt-cache, .terraform.lock.hcl | %{remove-item $_.fullname -recurse}`  
        On Linux:  
          `find . -type d -name ".terragrunt-cache" -prune -exec rm -rf {} \;`
  
      b. Generate a plan
        full plan
        `terragrunt hclfmt;terragrunt run-all plan -out plan.json --terragrunt-non-interactive --terragrunt-source-update`
        Partial plan
        `terragrunt hclfmt;terragrunt run-all plan -out plan.json --terragrunt-non-interactive --terragrunt-source-update --terragrunt-include-dir .\dir1-name\* --terragrunt-include-dir .\dir2-name\*`
        
        Notes:  
         - The `hclfmt` paramter will format and apply style to the terragrunt files. For terraform file, you have to execute the command `terraform fmt` individually to all .tf files  
         - If it is the first deployment, you will seen error messages when terraform is trying to retrieve data from remote state files. It will happend because the files are created yet. For example, when `data.terraform_remote_state.vpc_core` that can be found in some of the `import.tf` files

      c. read the plan  
         You can read the plan from the terminal but if it has output limitations, you will not be able to see all tasks to be executed. So you can use the command `show` to retrieve the information from the json file generated in the previous step.  
         `terragrunt run-all show -json`  

      d. apply changes  
         `terragrunt run-all apply plan.json`
         Note: if executing from pipeline use the flag `--terragrunt-non-interactive`<br/><br/><br/>

## Configuration files

1. YAML files  
  
    The YAML files are parsed by the Terraform yamldecode function and contain variable definitions
    e.g.: yamldecode(file("${get_terragrunt_dir()}/../../deployment.yml"))  

2. HCL Files  
   They are Terragrunt configuration files that uses same HCL syntax as Terraform  


3. YAML File scopes  

  - globa.yml      - variable definitions common to all deployments
  - deployment.yml - variable definitions common to all regions in a deployment
  - region.yml     - variable definitions common to a region in a deployment<br/><br/><br/>


## Maintenance and Troubleshooting
  
1. What if the command `terragrunt run-all plan` hangs without making any attempts to do anything
   - Enable debug by defining the variable `TF_LOG_PATH = ".\tf.log"` and executing the plan with debbuging parameter like the following:  
     `terragrunt run-all plan --terragrunt-log-level debug --terragrunt-debug`
   - Remove cache using the following commands and try again:
     - On Windows:  
        `get-ChildItem -Recurse -Include .terragrunt-cache | %{remove-item $_.fullname -recurse}; Get-ChildItem -Recurse -Include .terraform.lock.hcl, terragrunt-debug.tfvars.json, tf.log`  
     - On Linux:  
        `section to be updated`   
   - Check network connection e.g.: VPN
   - Check AWS credentials
   - Instead of running run-all, go to a especific deployment like the one below and execute terragrunt run-all plan
     `%REPO_ROOT%\deployments\%environment%\%region%\vpc-core`

2. Drift Detection   
   Use the terragrunt with the plan and show parameters to detect changes  
    `terragrunt hclfmt;terragrunt run-all plan -out plan.json --terragrunt-non-interactive`  
    `terragrunt run-all show -json`

3. Debuggubg
   Use the following parameter
   `--terragrunt-log-level debug --terragrunt-debug`
