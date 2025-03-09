# Configure AWS Provider
provider "aws" {
  region = "eu-west-3"
}

# Créer un bucket S3 pour héberger le site
resource "aws_s3_bucket" "portfolio_bucket" {
  bucket = "mon-portfolio-devops-123"
}

# Upload du fichier index.html
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.portfolio_bucket.bucket
  key          = "index.html" # Doit correspondre au suffixe de index_document
  source       = "site_Portfolio/index.html"
  content_type = "text/html"
  etag         = filemd5("site_Portfolio/index.html")
}

# Configuration website
resource "aws_s3_bucket_website_configuration" "portfolio" {
  bucket = aws_s3_bucket.portfolio_bucket.id

  index_document {
    suffix = "index.html"
  }
}

# Paramètres d'accès public
resource "aws_s3_bucket_public_access_block" "portfolio" {
  bucket                  = aws_s3_bucket.portfolio_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Origin Access Identity (OAI)
resource "aws_cloudfront_origin_access_identity" "portfolio" {
  comment = "Secure access via CloudFront"
}

# Politique d'accès S3
resource "aws_s3_bucket_policy" "portfolio" {
  bucket = aws_s3_bucket.portfolio_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { AWS = aws_cloudfront_origin_access_identity.portfolio.iam_arn },
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.portfolio_bucket.arn}/*"
      }
    ]
  })
}

# Distribution CloudFront
resource "aws_cloudfront_distribution" "portfolio_distribution" {
  origin {
    domain_name = aws_s3_bucket.portfolio_bucket.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.portfolio_bucket.bucket}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.portfolio.cloudfront_access_identity_path
    }
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.portfolio_bucket.bucket}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Versioning du bucket
resource "aws_s3_bucket_versioning" "portfolio_versioning" {
  bucket = aws_s3_bucket.portfolio_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Alarme CloudWatch
resource "aws_cloudwatch_metric_alarm" "portfolio_errors" {
  alarm_name          = "portfolio-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "4xxErrorRate"
  namespace           = "AWS/S3"
  period              = 300
  statistic           = "Average"
  threshold           = 5
  alarm_description   = "Alarme si taux d'erreurs élevé sur le portfolio"
  dimensions = {
    BucketName = aws_s3_bucket.portfolio_bucket.bucket
  }
}

# Enregistrement DNS Route53
resource "aws_route53_record" "portfolio" {
  zone_id = "Z09896161H6X24FICK9T2" # À remplacer par votre Hosted Zone ID
  name    = "portfolio.votredomaine.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.portfolio_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.portfolio_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}
