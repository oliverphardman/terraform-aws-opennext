data "archive_file" "this" {
  type = "zip"

  source_dir  = var.source_dir
  output_path = "${var.output_dir}${var.slug}.zip"

  depends_on = [data.external.this]
}

data "external" "this" {
  program = ["bash", "-c", "find ${var.source_dir} -type f -exec sha256sum {} \\; | sort | sha256sum | cut -d' ' -f1 | jq -R '{hash: .}'"]
}
