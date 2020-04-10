.EXPORT_ALL_VARIABLES:

#DN_PROJECT_STAGE						:= dev
#DN_PROJECT_STAGE						:= test
#DN_PROJECT_STAGE						:= prod
DN_PROJECT_STAGE						:= staging

DN_ROOT_PREFIX							:= the-daly-nugget-sam
DN_ROOT_PREFIX_PASCAL_CASE				:= TheDalyNuggetSam
DN_ROOT_PREFIX_NO_DASHES				:= $(subst -,,$(DN_ROOT_PREFIX))
DN_SERVICE_PREFIX_DASHES				:= $(DN_ROOT_PREFIX)-$(DN_PROJECT_STAGE)
DN_SERVICE_PREFIX_NO_DASHES				:= $(DN_ROOT_PREFIX_NO_DASHES)$(DN_PROJECT_STAGE)
DN_SERVICE_PREFIX_NO_DASHES_UPPER_T		:= $(subst th,Th,$(DN_ROOT_PREFIX_NO_DASHES))$(DN_PROJECT_STAGE)
DN_SERVICE_NAME							:= $(DN_ROOT_PREFIX)-service
DN_SERVICE_NAME_STAGE					:= $(DN_SERVICE_NAME)-$(DN_PROJECT_STAGE)

DN_DOMAIN								:= $(DN_ROOT_PREFIX_NO_DASHES).com
DN_SUBDOMAIN							:= $(DN_PROJECT_STAGE).${DN_DOMAIN}

DN_REVS_EMAIL_ADDRESS					:= thenuggrev@gmail.com

DN_S3_BUCKET_PREFIX						:= $(DN_SERVICE_NAME_STAGE)
DN_S3_STACK_OUTPUT_BUCKET				:= $(DN_S3_BUCKET_PREFIX)-stack-outputs
DN_S3_STACK_OUTPUT_FILE					:= stack-output
DN_SERVERLESS_OUTPUT_FILE		:= stack-output

DN_SES_CUSTOM_VERIFICATION_EMAIL_TEMPLATE_FILE		:= $(DN_SERVICE_NAME_STAGE)-verification-email-template-file.json
DN_SES_CUSTOM_VERIFICATION_EMAIL_TEMPLATE_NAME		:= $(DN_SERVICE_NAME_STAGE)-verification-email_template
DN_SES_EMAIL_RECEIPT_RULE_SET_NAME					:= $(DN_ROOT_PREFIX)-email-received-rule-set

DN_CICD_STACK					:= $(DN_SERVICE_NAME_STAGE)-ccid-stack
DN_CICD_STACK_TEMPLATE			:= $(DN_SERVICE_NAME_STAGE)-pipeline-template.yml

DN_HOME_DIR						:= $(DN_PROJECTS_DIR)/$(DN_ROOT_PREFIX_PASCAL_CASE)

DN_ASSETS_DIR					:= $(DN_HOME_DIR)/client/public/es6/assets
DN_APIG_SDK_DIR_NAME			:= apiGateway-js-sdk
DN_APIG_CLIENT_FILE				:= apigClient.js
DN_APIG_LOCAL_DIR_NAME			:= gateway
DN_APIG_DIR						:= $(DN_ASSETS_DIR)/$(DN_APIG_LOCAL_DIR_NAME)
DN_APIG_SDK_OUTPUT_FILE			:= $(DN_ASSETS_DIR)/$(DN_APIG_LOCAL_DIR_NAME).zip
DN_ORIGINAL_APIG_FILE			:= original_apig.js
DN_SERVICE_DIR					:= $(DN_HOME_DIR)/server/node/$(DN_SERVICE_NAME)
DN_SCRIPTS_DIR					:= $(DN_SERVICE_DIR)/scripts
DN_IMPORT_NUGGETS_DIR			:= $(DN_SCRIPTS_DIR)/NuggetImport
DN_SEED_NUGGET_BASE_SCRIPT		:= put_requests.js
DN_NUGGET_OF_THE_DAY_FILE		:= nod-table-item.json
NUGGET_OF_THE_DAY_TABLE			:= nugget-of-the-day

clean_cicd:
	aws s3api list-buckets --query 'Buckets[?starts_with(Name, `$(DN_S3_BUCKET_PREFIX)`) == `true`].[Name]' --output text | xargs -I {} $(SUDO) $(SW_INSTALL_PATH)aws s3 rb s3://{} --force
	aws s3api list-buckets --query 'Buckets[?starts_with(Name, `$(DN_SERVICE_NAME)`) == `true`].[Name]' --output text | xargs -I {} $(SUDO) $(SW_INSTALL_PATH)aws s3 rb s3://{} --force
	aws ses delete-custom-verification-email-template --template-name $(DN_SES_CUSTOM_VERIFICATION_EMAIL_TEMPLATE_NAME)
	aws ses list-identities --identity-type EmailAddress --output text | cut -f 2 | xargs -I {} $(SUDO) $(SW_INSTALL_PATH)aws ses delete-identity --identity {}
	aws ses list-identities --identity-type Domain --output text | cut -f 2 | xargs -I {} $(SUDO) $(SW_INSTALL_PATH)aws ses delete-identity --identity {}
	aws cloudformation delete-stack --stack-name $(DN_CICD_STACK)

clean_dn:
	aws s3 rm --recursive s3://the-daly-nugget-sam-service-staging-stack-outputs
	aws s3 rm --recursive s3://the-daly-nugget-sam-service-staging-emails
	aws s3 rm --recursive s3://the-daly-nugget-sam-service-staging-artifacts/*
	aws cloudformation delete-stack --stack-name the-daly-nugget-sam-service-staging
	aws ses delete-custom-verification-email-template --template-name $(DN_SES_CUSTOM_VERIFICATION_EMAIL_TEMPLATE_NAME)

clean_local:
	rm -rf ./node_modules
	rm -f ./package-lock.json
	npm install

clean_all:

deploy_pipeline_stack:
	aws s3 mb s3://the-daly-nugget-sam-service-staging-custom-cfn-resources
	aws s3 cp  --recursive ./custom/deploy/the-daly-nugget-sam-service-staging-custom-cfn-resources/pypy        s3://the-daly-nugget-sam-service-staging-custom-cfn-resources/pypy
	aws s3 cp  --recursive ./custom/deploy/the-daly-nugget-sam-service-staging-custom-cfn-resources/Briex   s3://the-daly-nugget-sam-service-staging-custom-cfn-resources/Briex
	aws cloudformation create-stack --stack-name $(DN_CICD_STACK) --template-body file://$(DN_CICD_STACK_TEMPLATE) --capabilities  CAPABILITY_IAM

complete_stack:
	aws ses delete-custom-verification-email-template --template-name the-daly-nugget-sam-service-staging-verification-email-template
	cd scripts && aws ses create-custom-verification-email-template  --cli-input-json file://the-daly-nugget-sam-service-staging-verification-email-template-file.json
	aws cloudformation list-exports > stack-output
	aws s3 cp ./stack-output s3://the-daly-nugget-sam-service-staging-stack-outputs/stack-output
	aws route53domains update-domain-nameservers --region us-east-1 --domain-name thedalynugget.com --nameservers $(aws cloudformation --output text list-exports --query 'Exports[?Name==`MyZoneServers`].Value'| sed 's/,/ Name=/g' | sed 's/^/Name=/')

populate_nugget_of_the_day:
	@printf "Seeding the nugget of the day table.\n"
	cd ./scripts/NuggetImport && aws dynamodb put-item --table-name nugget-of-the-day-sam-staging  --item file://nod-table-item.json

seed_nuggets:
	@printf "Seeding the nugget-base table.\n"
	cd ./scripts/NuggetImport && node  put_requests.js

delete_custom_verification_email_template:
	aws ses delete-custom-verification-email-template --template-name $(DN_SES_CUSTOM_VERIFICATION_EMAIL_TEMPLATE_NAME)

clean_cloud_watch:
	aws logs describe-log-groups --query 'logGroups[*].logGroupName' --output table | \
	awk '{print $2}' | grep -v ^$ | while read x; do  echo "deleting $x" ; aws logs delete-log-group --log-group-name $x; done

clean_cloud_watch_conditionally:
#	only delete loggroup name starting with /aws/lambda
	export AWS_DEFAULT_REGION=ap-northeast-1
	aws logs describe-log-groups --query 'logGroups[*].logGroupName' --output table | \
	awk '{print $2}' | grep ^/aws/lambda | while read x; do  echo "deleting $x" ; aws logs delete-log-group --log-group-name $x; done

nuke_cloud_watch:
	aws logs describe-log-groups --query 'logGroups[*].logGroupName' --output table | awk '{print $2}' | grep -v ^$ | while read x; do aws logs delete-log-group --log-group-name $x; done

populate_nugget_tables: populate_nugget_of_the_day seed_nuggets

get_client_sdk:
	rm -rf ./gateway
	aws apigateway get-sdk --rest-api-id 3xbgd3n2r8 --stage-name staging --sdk-type javascript apig.zip
	unzip apig.zip
	rm ./apig.zip
	mv apiGateway-js-sdk gateway

update_local_client_sdk:
	cp -rf ./gateway /Users/fas/MyStuff/Business/Projects/CurrentProjects/TheDalyNuggetSam/the-daly-nugget-sam-service-staging-repository/client/public/es6/assets/

update_s3_client_sdk:
	aws s3 cp --recursive ./gateway s3://staging.thedalynugget.com/assets

deploy_client: get_client_sdk update_local_client_sdk
	aws s3 cp --recursive /Users/fas/MyStuff/Business/Projects/CurrentProjects/TheDalyNuggetSam/the-daly-nugget-sam-service-staging-repository/client/public/es6/* s3://staging.thedalynugget.com/
