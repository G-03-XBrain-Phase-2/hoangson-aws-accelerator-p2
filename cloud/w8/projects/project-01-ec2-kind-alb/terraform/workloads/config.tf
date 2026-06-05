resource "kubernetes_config_map_v1" "app" {
  metadata {
    name      = "${var.app_name}-content"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
    labels    = local.labels
  }

  data = {
    "index.html" = <<-HTML
      <!doctype html>
      <html lang="vi">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>${var.student_name} - ${var.group_name}</title>
        <style>
          :root {
            font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            color: #111827;
            background: #f6f8fb;
          }

          * {
            box-sizing: border-box;
          }

          body {
            margin: 0;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 40px 18px;
            background:
              radial-gradient(circle at 18% 20%, rgba(59, 130, 246, 0.14), transparent 28%),
              radial-gradient(circle at 82% 80%, rgba(20, 184, 166, 0.12), transparent 30%),
              linear-gradient(135deg, #fbfdff 0%, #edf3fb 100%);
          }

          main {
            width: min(900px, 100%);
            border-radius: 8px;
            background: rgba(255, 255, 255, 0.82);
            border: 1px solid rgba(203, 213, 225, 0.9);
            box-shadow: 0 24px 80px rgba(15, 23, 42, 0.12);
            backdrop-filter: blur(16px);
            overflow: hidden;
          }

          header {
            padding: clamp(32px, 7vw, 72px);
          }

          .eyebrow {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            margin: 0 0 22px;
            padding: 8px 12px;
            border-radius: 999px;
            background: #e8f1ff;
            color: #1d4ed8;
            font-size: 13px;
            font-weight: 700;
            letter-spacing: 0.06em;
            text-transform: uppercase;
          }

          h1 {
            margin: 0;
            max-width: 760px;
            font-size: clamp(42px, 8vw, 76px);
            line-height: 0.98;
            letter-spacing: 0;
          }

          p {
            max-width: 660px;
            margin: 24px 0 0;
            color: #475569;
            font-size: clamp(18px, 2.5vw, 22px);
            line-height: 1.65;
          }

          .footer {
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
            margin-top: 34px;
          }

          .pill {
            padding: 10px 14px;
            border-radius: 999px;
            background: #ffffff;
            border: 1px solid #dbe4f0;
            color: #334155;
            font-size: 14px;
            font-weight: 600;
          }

          @media (max-width: 720px) {
            body {
              padding: 16px;
            }

            header {
              padding: 30px 24px;
            }
          }
        </style>
      </head>
      <body>
        <main>
          <header>
            <p class="eyebrow">Terraform AWS + Kubernetes Provider</p>
            <h1>${var.student_name}</h1>
            <p>Group ${var.group_name}. Demo app deployed to kind on EC2 and exposed through AWS ALB.</p>
            <div class="footer">
              <span class="pill">Cloud Lab</span>
              <span class="pill">Kubernetes</span>
              <span class="pill">Terraform</span>
            </div>
          </header>
        </main>
      </body>
      </html>
    HTML

    healthz = "ok"
  }
}
