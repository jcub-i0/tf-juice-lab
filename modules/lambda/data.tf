### Zip file containing EC2 Isolation Lambda function code
data "archive_file" "lambda_ec2_isolate_zip" {
  type        = "zip"
  source_file = "${path.module}/src/ec2_isolate/ec2_isolate_function.py"
  output_path = "${path.module}/src/ec2_isolate/ec2_isolate_function.zip"
}

### Zip file containing IP Enrichment Lambda function code
data "archive_file" "ip_enrich" {
  type        = "zip"
  source_file = "${path.module}/src/ip_enrich/ip_enrich_function.py"
  output_path = "${path.module}/src/ip_enrich/ip_enrich_function.zip"
}

### Zip file containing EC2 autostop func code
data "archive_file" "lambda_ec2_autostop_zip" {
  type        = "zip"
  source_file = "${path.module}/src/ec2_autostop/ec2_autostop.py"
  output_path = "${path.module}/src/ec2_autostop/ec2_autostop.zip"
}

data "archive_file" "layer" {
  type        = "zip"
  source_dir  = "${path.module}/src/layer"
  output_path = "${path.module}/src/layer.zip"
}