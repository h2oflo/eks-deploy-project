# locals {
#   site_bucket_name = "${var.domain_name}-site"
# }

# # S3 bucket (private, CloudFront reads via OAC)
# resource "aws_s3_bucket" "site" {
#   bucket = local.site_bucket_name
#   tags   = { Environment = "dev" }
# }

# resource "aws_s3_bucket_public_access_block" "site" {
#   bucket                  = aws_s3_bucket.site.id
#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

# resource "aws_s3_object" "index" {
#   bucket       = aws_s3_bucket.site.id
#   key          = "index.html"
#   content      = "<h1>Hello from CloudFront</h1>"
#   content_type = "text/html"
# }

# resource "aws_cloudfront_origin_access_control" "site" {
#   name                              = "${var.vpc_name}-oac"
#   origin_access_control_origin_type = "s3"
#   signing_behavior                  = "always"
#   signing_protocol                  = "sigv4"
# }

# # ACM cert must be us-east-1 for CloudFront
# resource "aws_acm_certificate" "site" {
#   provider          = aws.us_east_1
#   domain_name       = var.domain_name
#   validation_method = "DNS"
# }

# data "aws_route53_zone" "site" {
#   zone_id = var.route53_zone_id
# }

# resource "aws_route53_record" "cert_validation" {
#   for_each = {
#     for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
#       name  = dvo.resource_record_name
#       type  = dvo.resource_record_type
#       value = dvo.resource_record_value
#     }
#   }
#   zone_id = data.aws_route53_zone.site.zone_id
#   name    = each.value.name
#   type    = each.value.type
#   ttl     = 60
#   records = [each.value.value]
# }

# resource "aws_acm_certificate_validation" "site" {
#   provider                = aws.us_east_1
#   certificate_arn         = aws_acm_certificate.site.arn
#   validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
# }

# # CloudFront distribution
# resource "aws_cloudfront_distribution" "site" {
#   enabled             = true
#   default_root_object = "index.html"

#   origin {
#     domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
#     origin_id                = "s3-site"
#     origin_access_control_id = aws_cloudfront_origin_access_control.site.id
#   }

#   aliases = [var.domain_name]

#   viewer_certificate {
#     acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
#     ssl_support_method       = "sni-only"
#     minimum_protocol_version = "TLSv1.2_2021"
#   }

#   default_cache_behavior {
#     allowed_methods        = ["GET", "HEAD"]
#     cached_methods         = ["GET", "HEAD"]
#     target_origin_id       = "s3-site"
#     viewer_protocol_policy = "redirect-to-https"
#     compress               = true
#     cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6" # AWS managed CachingOptimized
#   }

#   restrictions {
#     geo_restriction {
#       restriction_type = "none"
#     }
#   }

#   price_class = "PriceClass_100"
#   tags        = { Environment = "dev" }
# }

# # Bucket policy: only this distribution can read
# resource "aws_s3_bucket_policy" "site" {
#   bucket = aws_s3_bucket.site.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Sid       = "AllowCloudFrontRead"
#       Effect    = "Allow"
#       Principal = { Service = "cloudfront.amazonaws.com" }
#       Action    = "s3:GetObject"
#       Resource  = "${aws_s3_bucket.site.arn}/*"
#       Condition = {
#         StringEquals = {
#           "AWS:SourceArn" = aws_cloudfront_distribution.site.arn
#         }
#       }
#     }]
#   })
# }

# # DNS record -> CloudFront
# resource "aws_route53_record" "site" {
#   zone_id = data.aws_route53_zone.site.zone_id
#   name    = var.domain_name
#   type    = "A"

#   alias {
#     name                   = aws_cloudfront_distribution.site.domain_name
#     zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
#     evaluate_target_health = false
#   }
# }

# output "site_url" {
#   description = "URL of the static site"
#   value       = "https://${aws_route53_record.site.name}"
# }
