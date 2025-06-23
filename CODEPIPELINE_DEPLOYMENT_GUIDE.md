# CodePipeline Deployment Guide

This guide covers setting up AWS CodePipeline for automated CI/CD deployment of your Hive Service Print Lambda function.

## 📋 **Prerequisites**

### **1. GitHub Repository**
- Repository containing your Lambda code
- GitHub Personal Access Token with `repo` permissions
- Branches set up for different environments:
  - `main` → Production
  - `staging` → Staging  
  - `develop` → Development

### **2. AWS Permissions**
Your AWS user/role needs permissions for:
- CloudFormation (full access)
- CodePipeline (full access)
- CodeBuild (full access)
- ECR (full access)
- IAM (create/manage roles)
- S3 (create/manage buckets)
- Lambda (full access)
- SQS (full access)

### **3. GitHub Personal Access Token**
Create a token with these permissions:
- `repo` (Full control of private repositories)
- `admin:repo_hook` (Full control of repository hooks)

## 🏗️ **Pipeline Architecture**

### **Pipeline Stages**
1. **Source**: GitHub repository trigger
2. **Build**: Docker image build and push to ECR
3. **Deploy**: CloudFormation stack deployment

### **Resources Created**
- **CodePipeline**: Main pipeline orchestration
- **CodeBuild Projects**: Build and deploy stages
- **ECR Repository**: Docker image storage
- **S3 Bucket**: Pipeline artifacts storage
- **IAM Roles**: Service roles for pipeline components
- **CloudWatch**: Logs and monitoring

## 🚀 **Quick Setup**

### **Single Environment**
```bash
# Deploy development pipeline
./deploy-pipeline.sh -e dev -o your-github-org -t ghp_your_token

# Deploy production pipeline  
./deploy-pipeline.sh -e prod -o your-github-org -t ghp_your_token
```

### **All Environments**
```bash
# Deploy all environments at once
./setup-multi-env-pipeline.sh -o your-github-org -t ghp_your_token
```

## 📝 **Step-by-Step Setup**

### **Step 1: Prepare GitHub Repository**

1. **Push your code to GitHub**:
   ```bash
   git remote add origin https://github.com/your-org/hive-service-print.git
   git push -u origin main
   ```

2. **Create environment branches**:
   ```bash
   # Create develop branch
   git checkout -b develop
   git push -u origin develop
   
   # Create staging branch
   git checkout -b staging  
   git push -u origin staging
   ```

3. **Get GitHub Personal Access Token**:
   - Go to GitHub Settings → Developer settings → Personal access tokens
   - Generate new token with `repo` and `admin:repo_hook` permissions
   - Copy the token (you'll need it for deployment)

### **Step 2: Configure Parameters**

Update the CodePipeline parameter files with your information:

**`codepipeline-parameters-dev.json`**:
```json
[
  {
    "ParameterKey": "GitHubOwner",
    "ParameterValue": "your-github-username-or-org"
  },
  {
    "ParameterKey": "GitHubRepo", 
    "ParameterValue": "hive-service-print"
  },
  {
    "ParameterKey": "GitHubToken",
    "ParameterValue": "ghp_your_personal_access_token"
  }
]
```

### **Step 3: Deploy Pipeline Infrastructure**

```bash
# Deploy development pipeline
./deploy-pipeline.sh \
  -e dev \
  -r eu-west-2 \
  -o your-github-org \
  -t ghp_your_token

# Deploy production pipeline
./deploy-pipeline.sh \
  -e prod \
  -r eu-west-2 \
  -o your-github-org \
  -t ghp_your_token
```

### **Step 4: Verify Deployment**

1. **Check CloudFormation stacks**:
   ```bash
   aws cloudformation list-stacks --region eu-west-2 --query 'StackSummaries[?contains(StackName, `hive-pipeline`)].{Name:StackName,Status:StackStatus}'
   ```

2. **Check pipeline status**:
   ```bash
   aws codepipeline list-pipelines --region eu-west-2
   ```

3. **View in AWS Console**:
   - Go to CodePipeline console
   - You should see your pipelines listed

## 🔧 **Pipeline Configuration**

### **Build Stage Configuration**

The build stage uses CodeBuild with these specifications:
- **Runtime**: Amazon Linux 2
- **Compute**: BUILD_GENERAL1_MEDIUM
- **Docker**: Enabled (privileged mode)
- **Environment Variables**:
  - `AWS_ACCOUNT_ID`: Your AWS account ID
  - `IMAGE_REPO_NAME`: ECR repository name
  - `ENVIRONMENT`: Target environment

### **Build Process**
1. **Pre-build**:
   - Login to ECR
   - Set image tags and URIs
   
2. **Build**:
   - Restore .NET dependencies
   - Build .NET application
   - Build Docker image
   - Tag images for ECR

3. **Post-build**:
   - Push images to ECR
   - Update CloudFormation parameters
   - Create deployment artifacts

### **Deploy Stage Configuration**

The deploy stage uses CloudFormation to:
1. Validate the template
2. Create or update the Lambda stack
3. Wait for deployment completion
4. Output stack information

## 📊 **Monitoring & Troubleshooting**

### **Pipeline Monitoring**

**View pipeline executions**:
```bash
aws codepipeline list-pipeline-executions \
  --pipeline-name hive-service-print-pipeline-dev \
  --region eu-west-2
```

**Get execution details**:
```bash
aws codepipeline get-pipeline-execution \
  --pipeline-name hive-service-print-pipeline-dev \
  --pipeline-execution-id execution-id \
  --region eu-west-2
```

### **CodeBuild Logs**

**View build logs**:
```bash
aws logs tail /aws/codebuild/hive-service-print-build-dev --follow --region eu-west-2
```

**View deploy logs**:
```bash
aws logs tail /aws/codebuild/hive-service-print-deploy-dev --follow --region eu-west-2
```

### **Common Issues**

#### **1. GitHub Webhook Not Working**
- Verify GitHub token has correct permissions
- Check webhook configuration in GitHub repository settings
- Ensure branch names match pipeline configuration

#### **2. ECR Push Failed**
- Verify ECR repository exists
- Check CodeBuild service role has ECR permissions
- Ensure Docker daemon is running in CodeBuild

#### **3. CloudFormation Deployment Failed**
- Check CloudFormation events for error details
- Verify parameter values are correct
- Ensure CodeBuild role has CloudFormation permissions

#### **4. Lambda Function Not Updated**
- Verify ECR image URI is correct in parameters
- Check Lambda function configuration
- Ensure Event Source Mapping is active

## 🔄 **Pipeline Workflow**

### **Development Workflow**
1. **Developer pushes to `develop` branch**
2. **GitHub webhook triggers dev pipeline**
3. **CodeBuild builds and pushes image**
4. **CloudFormation deploys to dev environment**
5. **Developer tests in dev environment**

### **Staging Workflow**
1. **Merge `develop` → `staging` branch**
2. **GitHub webhook triggers staging pipeline**
3. **Automated deployment to staging environment**
4. **QA testing in staging environment**

### **Production Workflow**
1. **Merge `staging` → `main` branch**
2. **GitHub webhook triggers production pipeline**
3. **Automated deployment to production environment**
4. **Production monitoring and validation**

## 🔒 **Security Best Practices**

### **GitHub Token Security**
- Use GitHub Secrets or AWS Secrets Manager for tokens
- Rotate tokens regularly
- Limit token permissions to minimum required

### **IAM Roles**
- CodeBuild and CodePipeline roles follow least privilege
- Separate roles for different environments
- Regular audit of permissions

### **ECR Security**
- Image scanning enabled
- Lifecycle policies to clean up old images
- Encryption at rest enabled

## 💰 **Cost Optimization**

### **CodeBuild Costs**
- **Development**: ~$5-10/month (frequent builds)
- **Production**: ~$2-5/month (less frequent builds)

### **CodePipeline Costs**
- **Per pipeline**: $1/month per active pipeline
- **Total for 3 environments**: ~$3/month

### **Storage Costs**
- **ECR**: ~$1-3/month for image storage
- **S3 Artifacts**: ~$0.50-1/month

**Total Estimated Cost**: ~$10-20/month for complete CI/CD setup

## 📈 **Advanced Configuration**

### **Manual Approval Gates**

Add manual approval before production deployment:

```yaml
- Name: Approval
  Actions:
    - Name: ManualApproval
      ActionTypeId:
        Category: Approval
        Owner: AWS
        Provider: Manual
        Version: '1'
      Configuration:
        CustomData: 'Please review and approve production deployment'
```

### **Parallel Deployments**

Deploy to multiple environments in parallel:

```yaml
- Name: ParallelDeploy
  Actions:
    - Name: DeployDev
      ActionTypeId:
        Category: Build
        Owner: AWS
        Provider: CodeBuild
        Version: '1'
      RunOrder: 1
    - Name: DeployStaging
      ActionTypeId:
        Category: Build
        Owner: AWS
        Provider: CodeBuild
        Version: '1'
      RunOrder: 1
```

### **Integration Testing**

Add automated testing stage:

```yaml
- Name: Test
  Actions:
    - Name: IntegrationTests
      ActionTypeId:
        Category: Build
        Owner: AWS
        Provider: CodeBuild
        Version: '1'
      Configuration:
        ProjectName: hive-service-print-tests
```

## 🎯 **Best Practices**

### **Branch Strategy**
- `main`: Production-ready code
- `staging`: Pre-production testing
- `develop`: Active development
- `feature/*`: Feature branches

### **Deployment Strategy**
- **Development**: Deploy on every push
- **Staging**: Deploy on merge to staging
- **Production**: Deploy on merge to main with approval

### **Monitoring**
- Set up CloudWatch alarms for pipeline failures
- Monitor build times and success rates
- Track deployment frequency and lead time

### **Testing**
- Unit tests in build stage
- Integration tests after deployment
- Smoke tests in production

## ✅ **Deployment Checklist**

### **Pre-Deployment**
- [ ] GitHub repository created and code pushed
- [ ] GitHub Personal Access Token created
- [ ] AWS CLI configured with appropriate permissions
- [ ] Parameter files updated with correct values

### **Pipeline Setup**
- [ ] CodePipeline infrastructure deployed
- [ ] ECR repository created
- [ ] GitHub webhooks configured
- [ ] IAM roles and permissions verified

### **Post-Deployment**
- [ ] Pipeline executions successful
- [ ] Lambda functions deployed correctly
- [ ] CloudWatch logs and metrics working
- [ ] Integration tests passing

### **Ongoing Maintenance**
- [ ] Monitor pipeline success rates
- [ ] Rotate GitHub tokens regularly
- [ ] Update build images and dependencies
- [ ] Review and optimize costs

Your CodePipeline setup is now ready for automated CI/CD deployment! 🚀
