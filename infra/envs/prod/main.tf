module "cdn" {
  source = "../../modules/cdn"

  bucket_name = var.bucket_name
}
