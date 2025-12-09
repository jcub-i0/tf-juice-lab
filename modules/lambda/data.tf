### Zip file containing Lambda function code
data "archive_file" "lambda_ec2_isolate_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/ec2_isolate/ec2_isolate_function.py"
  output_path = "${path.module}/lambda/ec2_isolate/ec2_isolate_function.zip"
}