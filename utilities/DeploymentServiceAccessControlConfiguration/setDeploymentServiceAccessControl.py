import logging
import boto3
import json
import os 

folder = os.path.dirname(os.path.realpath(__file__))
configFile = os.path.join(folder, 'accounts.json')
deploymentServiceRoleName = 'MyDeploymentService'

try:
    with open(configFile, 'r') as reader:
        accounts = json.loads(reader.read())
except IOError:
        raise IOError('IO operation failed')
except json.JSONDecodeError:
    raise json.JSONDecodeError('Invalid Json file')

if 'deployment' not in accounts and 'targets' not in accounts:
    raise ValueError('Invalid configuration file (json schema)')

deploymentServiceConfigProperties = list((accounts['deployment']).keys())
if not ('accountAlias' in deploymentServiceConfigProperties and 'accountNumber' in deploymentServiceConfigProperties and 'localAWSProfileName' in deploymentServiceConfigProperties):
    raise ValueError('Invalid configuration file (json schema)')

for targetAccountConfig in accounts['targets']:
    targetAccountConfigProperties = list(targetAccountConfig.keys())
    if not ('accountAlias' in targetAccountConfigProperties and 'accountNumber' in targetAccountConfigProperties and 'localAWSProfileName' in targetAccountConfigProperties):
        raise ValueError('Invalid configuration file (json schema)')

deploymentAccountConfig = accounts['deployment']
targetAccountsConfig = accounts['targets']
deploymentServiceTrustEntityPrincipal = f"arn:aws:iam::{deploymentAccountConfig['accountNumber']}:root"
targetAccountTrustEntityPrincipal = f"arn:aws:iam::{deploymentAccountConfig['accountNumber']}:role/{deploymentServiceRoleName}"

def setAccessControl(session, trustEntityPrincipal):
    
    stsClient = session.client('sts')            
    userIdentity = stsClient.get_caller_identity()
    message = f"Configuring deployment service access control for account {userIdentity['Account']} using user {userIdentity['Arn']}"
    logging.info(message)
    print(message)

    iamClient = session.client('iam')
    assumeRolePolicyDocument = json.dumps({
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "AWS": f'{trustEntityPrincipal}'
                },
                "Action": "sts:AssumeRole",
                "Condition": {}
            }
        ]
    })

    response = {}
    try:
        response = iamClient.create_role(
            RoleName=f'{deploymentServiceRoleName}',
            AssumeRolePolicyDocument=f'{assumeRolePolicyDocument}',
            Description='Role for DevOps automated task deployments service'
        )
    except iamClient.exceptions.EntityAlreadyExistsException:
        logging.info(f'The role {deploymentServiceRoleName} already exists')
    except Exception as error:
        raise error

    response = {}
    try:
        response = iamClient.attach_role_policy(
            RoleName=f'{deploymentServiceRoleName}',
            PolicyArn='arn:aws:iam::aws:policy/AdministratorAccess'
        )
        if response['ResponseMetadata']['HTTPStatusCode'] == 200:
            message = f'The AWS managed policy "AdministratorAccess" was successful attached to the role {deploymentServiceRoleName}'
            logging.info(message)
            print(message)
        else:
            message = f'Something is wrong. Check the HTTP response'
            logging.info(message)
            print(message)

    except Exception as error:
        raise error

#############################################################
###### Deployment Service Access Control Configuration ######
#############################################################

deploymentServiceSession = boto3.session.Session(profile_name=deploymentAccountConfig['localAWSProfileName'])
setAccessControl(deploymentServiceSession, deploymentServiceTrustEntityPrincipal)

#############################################################
######## Target Accounts Access Control Configuration #######
#############################################################

for targetAccountConfig in targetAccountsConfig:

    targetAccountSession = boto3.session.Session(profile_name=targetAccountConfig['localAWSProfileName'])
    setAccessControl(targetAccountSession, targetAccountTrustEntityPrincipal)    


print('End of access control configuration')