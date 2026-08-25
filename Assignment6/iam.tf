# --------------------------------------------------
# IAM User
# --------------------------------------------------

resource "aws_iam_user" "assignment6_admin" {
  name = "assignment6-admin"

  tags = {
    Name = "Assignment6-Admin-User"
  }
}

# --------------------------------------------------
# Administrator Access
# --------------------------------------------------

resource "aws_iam_user_policy_attachment" "administrator_access" {
  user       = aws_iam_user.assignment6_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# --------------------------------------------------
# EC2 Full Access
# --------------------------------------------------

resource "aws_iam_user_policy_attachment" "ec2_full_access" {
  user       = aws_iam_user.assignment6_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}
