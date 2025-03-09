# Configure AWS Provider
provider "aws" {
  region = "eu-west-3"
}

# Créer un bucket S3 pour héberger le site
resource "aws_s3_bucket" "portfolio_bucket" {
  bucket = "mon-portfolio-devops-123"
  #acl    = "public-read"
}
# Configuration website séparée (plus récente)
resource "aws_s3_bucket_website_configuration" "portfolio" {
  bucket = aws_s3_bucket.portfolio_bucket.id

  index_document {
    suffix = "index.html"
  }
}

# Public Access Block ajusté
resource "aws_s3_bucket_public_access_block" "portfolio" {
  bucket = aws_s3_bucket.portfolio_bucket.id

  block_public_acls       = false # ← Modifié
  block_public_policy     = false # ← Modifié
  ignore_public_acls      = false
  restrict_public_buckets = false
}


# Créer une Origin Access Identity (OAI)
resource "aws_cloudfront_origin_access_identity" "portfolio" {
  comment = "Secure access via CloudFront"
}

# Politique S3 restreinte à CloudFront uniquement
resource "aws_s3_bucket_policy" "portfolio" {
  bucket = aws_s3_bucket.portfolio_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.portfolio.iam_arn
        },
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.portfolio_bucket.arn}/*"
      }
    ]
  })
}

# Configuration CloudFront avec OAI
resource "aws_cloudfront_distribution" "portfolio_distribution" {
  origin {
    domain_name = aws_s3_bucket.portfolio_bucket.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.portfolio_bucket.bucket}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.portfolio.cloudfront_access_identity_path
    }
  }
  # ... (garder le reste de la config existante)
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
# Activer la versioning du bucket
resource "aws_s3_bucket_versioning" "portfolio_versioning" {
  bucket = aws_s3_bucket.portfolio_bucket.id
  versioning_configuration {
    status = "Enabled"
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
  zone_id = "Z09896161H6X24FICK9T2"
  name    = "portfolio.votredomaine.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.portfolio_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.portfolio_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}
