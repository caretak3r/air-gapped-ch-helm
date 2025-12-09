#!/bin/bash

# IRSA Setup Script for ClickHouse S3 Integration
# This script creates an IAM role with least-privilege access to S3 buckets
# and associates it with a Kubernetes service account using IRSA

set -e

# Configuration - Modify these variables for your environment
CLUSTER_NAME="your-eks-cluster-name"
REGION="us-east-1"
NAMESPACE="clickhouse"
SERVICE_ACCOUNT_NAME="clickhouse-operator"
BUCKET_NAME="my-metrics-bucket"
RAW_PREFIX="raw"
PROCESSED_PREFIX="processed"
ARCHIVE_PREFIX="archive"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials are not configured. Please run 'aws configure'."
        exit 1
    fi
    
    log_info "Prerequisites check passed."
}

# Create IAM policy with least privilege
create_iam_policy() {
    log_info "Creating IAM policy for S3 access..."
    
    # Create policy document
    cat > /tmp/clickhouse-s3-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::${BUCKET_NAME}",
                "arn:aws:s3:::${BUCKET_NAME}/*"
            ],
            "Condition": {
                "StringLike": {
                    "s3:prefix": [
                        "${RAW_PREFIX}/*",
                        "${PROCESSED_PREFIX}/*",
                        "${ARCHIVE_PREFIX}/*"
                    ]
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::${BUCKET_NAME}"
            ],
            "Condition": {
                "StringLike": {
                    "s3:prefix": [
                        "${RAW_PREFIX}/",
                        "${PROCESSED_PREFIX}/",
                        "${ARCHIVE_PREFIX}/"
                    ]
                }
            }
        }
    ]
}
EOF
    
    # Create the policy
    POLICY_NAME="ClickHouseS3Policy-${BUCKET_NAME}"
    
    # Check if policy already exists
    if aws iam list-policies --query "Policies[?PolicyName=='${POLICY_NAME}'].Arn" --output text | grep -q "arn:aws:iam"; then
        log_warn "Policy ${POLICY_NAME} already exists. Deleting it first..."
        aws iam delete-policy --policy-arn "$(aws iam list-policies --query "Policies[?PolicyName=='${POLICY_NAME}'].Arn" --output text)"
    fi
    
    POLICY_ARN=$(aws iam create-policy \
        --policy-name "${POLICY_NAME}" \
        --policy-document file:///tmp/clickhouse-s3-policy.json \
        --query 'Policy.Arn' \
        --output text)
    
    log_info "IAM policy created: ${POLICY_ARN}"
    echo "${POLICY_ARN}"
}

# Get OIDC provider info for EKS cluster
get_oidc_info() {
    log_info "Getting OIDC provider information..."
    
    OIDC_PROVIDER_URL=$(aws eks describe-cluster \
        --name "${CLUSTER_NAME}" \
        --region "${REGION}" \
        --query "cluster.identity.oidc.issuer" \
        --output text)
    
    # Remove https:// prefix if present
    OIDC_PROVIDER_URL_WITHOUT_HTTPS=${OIDC_PROVIDER_URL#https://}
    
    OIDC_PROVIDER_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):oidc-provider/${OIDC_PROVIDER_URL_WITHOUT_HTTPS}"
    
    log_info "OIDC Provider URL: ${OIDC_PROVIDER_URL}"
    log_info "OIDC Provider ARN: ${OIDC_PROVIDER_ARN}"
    
    echo "${OIDC_PROVIDER_URL}"
}

# Create IAM role for service account
create_iam_role() {
    local oidc_url="$1"
    local policy_arn="$2"
    
    log_info "Creating IAM role for service account..."
    
    # Trust relationship
    cat > /tmp/trust-relationship.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "${oidc_url}"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "${oidc_url#https://}:sub": "system:serviceaccount:${NAMESPACE}:${SERVICE_ACCOUNT_NAME}"
                }
            }
        }
    ]
}
EOF
    
    # Create role
    ROLE_NAME="ClickHouseS3Role-${BUCKET_NAME}"
    
    # Delete existing role if it exists
    if aws iam get-role --role-name "${ROLE_NAME}" &>/dev/null; then
        log_warn "Role ${ROLE_NAME} already exists. Deleting it first..."
        # Detach policies first
        aws iam detach-role-policy --role-name "${ROLE_NAME}" --policy-arn "${policy_arn}"
        aws iam delete-role --role-name "${ROLE_NAME}"
    fi
    
    ROLE_ARN=$(aws iam create-role \
        --role-name "${ROLE_NAME}" \
        --assume-role-policy-document file:///tmp/trust-relationship.json \
        --query 'Role.Arn' \
        --output text)
    
    # Attach policy to role
    aws iam attach-role-policy \
        --role-name "${ROLE_NAME}" \
        --policy-arn "${policy_arn}"
    
    log_info "IAM role created: ${ROLE_ARN}"
    echo "${ROLE_ARN}"
}

# Create or update Kubernetes service account
create_service_account() {
    local role_arn="$1"
    
    log_info "Creating/updating Kubernetes service account..."
    
    # Create namespace if it doesn't exist
    kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
    
    # Create service account with IAM role annotation
    cat > /tmp/service-account.yaml << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${SERVICE_ACCOUNT_NAME}
  namespace: ${NAMESPACE}
  annotations:
    eks.amazonaws.com/role-arn: ${role_arn}
EOF
    
    kubectl apply -f /tmp/service-account.yaml
    
    log_info "Service account ${SERVICE_ACCOUNT_NAME} created/updated in namespace ${NAMESPACE}"
}

# Update Helm values for IRSA
update_helm_values() {
    log_info "Generating Helm values update..."
    
    cat << EOF

# Add this to your clickhouse-operator values.yaml:

clickhouse:
  serviceAccount:
    create: true
    name: ${SERVICE_ACCOUNT_NAME}
    annotations:
      eks.amazonaws.com/role-arn: $(aws iam get-role --role-name "ClickHouseS3Role-${BUCKET_NAME}" --query 'Role.Arn' --output text)

# Update S3 configuration to use IRSA
clickhouse:
  extraConfig: |
    <clickhouse>
      <storage_configuration>
        <disks>
          <s3_disk>
            <type>s3</type>
            <endpoint>https://s3.amazonaws.com/${BUCKET_NAME}/</endpoint>
            <!-- Access credentials will be automatically provided via IRSA -->
            <access_key_id></access_key_id>
            <secret_access_key></secret_access_key>
            <region>${REGION}</region>
          </s3_disk>
        </disks>
        <policies>
          <s3_policy>
            <volumes>
              <default_volume>
                <disk>s3_disk</disk>
              </default_volume>
            </volumes>
          </s3_policy>
        </policies>
      </storage_configuration>
    </clickhouse>

EOF
}

# Test IRSA configuration
test_irsa() {
    log_info "Testing IRSA configuration..."
    
    # Create a test pod
    cat > /tmp/test-irsa.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-irsa
  namespace: ${NAMESPACE}
spec:
  serviceAccountName: ${SERVICE_ACCOUNT_NAME}
  containers:
  - name: test
    image: amazon/aws-cli:latest
    command: ["sleep", "3600"]
  restartPolicy: Never
EOF
    
    kubectl apply -f /tmp/test-irsa.yaml
    
    log_info "Waiting for test pod to be ready..."
    kubectl wait --for=condition=Ready pod/test-irsa -n "${NAMESPACE}" --timeout=60s
    
    # Test S3 access
    log_info "Testing S3 access..."
    if kubectl exec -n "${NAMESPACE}" test-irsa -- aws s3 ls "s3://${BUCKET_NAME}/${RAW_PREFIX}/"; then
        log_info "✅ S3 access test passed!"
    else
        log_error "❌ S3 access test failed!"
        return 1
    fi
    
    # Clean up test pod
    kubectl delete pod test-irsa -n "${NAMESPACE}"
    
    log_info "IRSA configuration test completed successfully!"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary files..."
    rm -f /tmp/clickhouse-s3-policy.json /tmp/trust-relationship.json /tmp/service-account.yaml /tmp/test-irsa.yaml
}

# Main execution
main() {
    log_info "Starting IRSA setup for ClickHouse S3 integration..."
    echo "=============================================="
    
    # Validate inputs
    if [[ "$CLUSTER_NAME" == "your-eks-cluster-name" ]]; then
        log_error "Please update CLUSTER_NAME variable with your actual EKS cluster name."
        exit 1
    fi
    
    # Execute steps
    check_prerequisites
    oidc_url=$(get_oidc_info)
    policy_arn=$(create_iam_policy)
    role_arn=$(create_iam_role "$oidc_url" "$policy_arn")
    create_service_account "$role_arn"
    update_helm_values
    
    echo ""
    log_info "IRSA setup completed!"
    echo ""
    log_warn "IMPORTANT: Update your Helm values.yaml with the configuration shown above."
    echo ""
    
    # Ask user if they want to test
    read -p "Do you want to test the IRSA configuration? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        test_irsa
    fi
    
    cleanup
    log_info "IRSA setup script completed."
}

# Run main function
main "$@"
