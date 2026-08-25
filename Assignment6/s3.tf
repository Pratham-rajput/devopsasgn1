# --------------------------------------------------
# S3 Static Website
# --------------------------------------------------

resource "aws_s3_bucket" "assignment6_website" {
  bucket_prefix = "assignment6-static-website-"

  tags = {
    Name = "Assignment6-Static-Website"
  }
}

# --------------------------------------------------
# Disable S3 Block Public Access
# --------------------------------------------------

resource "aws_s3_bucket_public_access_block" "assignment6_website" {
  bucket = aws_s3_bucket.assignment6_website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# --------------------------------------------------
# Website Configuration
# --------------------------------------------------

resource "aws_s3_bucket_website_configuration" "assignment6_website" {
  bucket = aws_s3_bucket.assignment6_website.id

  index_document {
    suffix = "index.html"
  }
}

# --------------------------------------------------
# Upload index.html
# --------------------------------------------------

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.assignment6_website.id
  key          = "index.html"
  source       = "${path.module}/website/index.html"
  content_type = "text/html"
}

# --------------------------------------------------
# Public Read Policy
# --------------------------------------------------

resource "aws_s3_bucket_policy" "assignment6_website" {
  bucket = aws_s3_bucket.assignment6_website.id

  depends_on = [
    aws_s3_bucket_public_access_block.assignment6_website
  ]

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "PublicReadGetObject"
        Effect = "Allow"

        Principal = "*"

        Action = [
          "s3:GetObject"
        ]

        Resource = "${aws_s3_bucket.assignment6_website.arn}/*"
      }
    ]
  })
}
