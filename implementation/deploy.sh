#!/bin/bash
set -e
source "$(dirname "$0")/config.env"
ACCT=$(aws sts get-caller-identity --query Account --output text)

echo "══════════════════════════════════════════════════"
echo " $PROJECT | $REGION | Account: $ACCT"
echo "══════════════════════════════════════════════════"

case "$1" in

setup)
  echo "► Installing tools..."
  sudo apt-get update -y -qq
  sudo apt-get install -y -qq unzip docker.io jq
  # Terraform
  wget -qO- https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip > /tmp/tf.zip
  sudo unzip -qo /tmp/tf.zip -d /usr/local/bin && rm /tmp/tf.zip
  # Docker
  sudo systemctl enable docker && sudo systemctl start docker
  sudo usermod -aG docker $USER
  echo "✅ Done. Log out & back in for docker group, then run: ./deploy.sh up"
  ;;

up)
  echo "► Deploying all infrastructure..."
  cd "$(dirname "$0")/tf"
  terraform init -input=false
  terraform apply -auto-approve -input=false \
    -var="project=$PROJECT" -var="region=$REGION" -var="env=$ENV"
  echo ""
  terraform output
  echo ""
  # Build & push container
  echo "► Building container..."
  cd ../app
  docker build -t ${PROJECT}-summarisation:v1 .
  ECR="${ACCT}.dkr.ecr.${REGION}.amazonaws.com/${PROJECT}-summarisation"
  aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin "${ACCT}.dkr.ecr.${REGION}.amazonaws.com"
  docker tag ${PROJECT}-summarisation:v1 ${ECR}:v1
  docker push ${ECR}:v1
  echo ""
  echo "══════════════════════════════════════════════════"
  echo " ✅ DEPLOYED — Take screenshots now"
  echo " Console: https://${REGION}.console.aws.amazon.com"
  echo " Destroy: ./deploy.sh down"
  echo "══════════════════════════════════════════════════"
  ;;

down)
  echo "► Destroying everything..."
  cd "$(dirname "$0")/tf"
  # Empty buckets first
  for b in $(aws s3 ls | grep "$PROJECT" | awk '{print $3}'); do
    aws s3 rm "s3://$b" --recursive --quiet 2>/dev/null || true
  done
  # Delete ECR images
  aws ecr batch-delete-image --repository-name "${PROJECT}-summarisation" \
    --image-ids imageTag=v1 --region $REGION 2>/dev/null || true
  # Terraform destroy
  terraform destroy -auto-approve -input=false \
    -var="project=$PROJECT" -var="region=$REGION" -var="env=$ENV"
  echo "✅ All destroyed. $0 cost."
  ;;

*)
  echo "Usage: ./deploy.sh [setup|up|down]"
  ;;
esac
