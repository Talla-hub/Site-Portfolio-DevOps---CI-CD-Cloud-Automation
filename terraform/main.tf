# Configure AWS Provider
provider "aws" {
  region = "eu-west-3"
}

# Créer un bucket S3 pour héberger le site
resource "aws_s3_bucket" "portfolio_bucket" {
  bucket = "mon-portfolio-devops-123456"
  #acl    = "public-read"
  # Ajoutez une politique de bucket pour gérer les autorisations d'accès
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::mon-portfolio-devops-123/*"
      }
    ]
  })

  website {
    index_document = "index.html"
  }
}
resource "aws_s3_bucket_public_access_block" "portfolio_bucket_public_access_block" {
  bucket                  = aws_s3_bucket.portfolio_bucket.id
  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Activer la versioning du bucket
resource "aws_s3_bucket_versioning" "portfolio_versioning" {
  bucket = aws_s3_bucket.portfolio_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Déployer via CloudFront (CDN)
resource "aws_cloudfront_distribution" "portfolio_distribution" {
  origin {
    domain_name = aws_s3_bucket.portfolio_bucket.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.portfolio_bucket.bucket}"
  }

  enabled = true
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
# Créer une alarme CloudWatch pour les erreurs 4xx/5xx
resource "aws_cloudwatch_metric_alarm" "portfolio_errors" {
  alarm_name          = "portfolio-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "4xxErrorRate"
  namespace           = "AWS/S3"
  period              = "300"
  statistic           = "Average"
  threshold           = "5"
  alarm_description   = "Alarme si taux d'erreurs élevé sur le portfolio"
  dimensions = {
    BucketName = aws_s3_bucket.portfolio_bucket.bucket
  }
}
# Route 53 pour le DNS
resource "aws_route53_record" "portfolio" {
  zone_id = "VOTRE_ZONE_ID"
  name    = "portfolio.votredomaine.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.portfolio_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.portfolio_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}
