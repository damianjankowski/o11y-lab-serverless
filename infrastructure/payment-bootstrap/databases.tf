module "dynamodb_table_payment_event" {
  source       = "../modules/terraform-aws-dynamodb"
  table_name   = "PaymentEvent"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "checkout_id"
  range_key    = null

  attributes = [
    { name = "checkout_id", type = "S" }
  ]

  enable_ttl = false
  tags       = var.tags
}

module "dynamodb_table_payment_order" {
  source       = "../modules/terraform-aws-dynamodb"
  table_name   = "PaymentOrder"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "payment_order_id"
  range_key    = null

  attributes = [
    { name = "payment_order_id", type = "S" },
    { name = "checkout_id", type = "S" }
  ]

  global_secondary_indexes = [
    {
      name               = "checkout_id-index"
      hash_key           = "checkout_id"
      range_key          = null
      projection_type    = "ALL"
      non_key_attributes = []
      read_capacity      = null
      write_capacity     = null
    }
  ]

  enable_ttl = false
  tags       = var.tags
}

module "dynamodb_table_wallet" {
  source       = "../modules/terraform-aws-dynamodb"
  table_name   = "Wallet"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "merchant_id"
  range_key    = null

  attributes = [
    { name = "merchant_id", type = "S" }
  ]

  enable_ttl = false
  tags       = var.tags
}