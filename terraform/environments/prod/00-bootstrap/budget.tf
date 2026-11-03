# Automated Subscription-level Budget Alert Guardrail
resource "azurerm_consumption_budget_subscription" "credit_guardrail" {
  name            = "budget-${var.project_name}-${var.environment}-guardrail"
  subscription_id = data.azurerm_subscription.current.id

  amount     = var.budget_amount
  time_grain = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }

  # Tier 1 Alert: 50% Actual Spend ($2.50)
  notification {
    enabled        = true
    threshold      = 50.0
    operator       = "EqualTo"
    threshold_type = "Actual"
    contact_emails = var.budget_notification_emails
  }

  # Tier 2 Alert: 80% Actual Spend ($4.00)
  notification {
    enabled        = true
    threshold      = 80.0
    operator       = "EqualTo"
    threshold_type = "Actual"
    contact_emails = var.budget_notification_emails
  }

  # Tier 3 Alert: 100% Forecasted Spend ($5.00 early warning)
  notification {
    enabled        = true
    threshold      = 100.0
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_emails = var.budget_notification_emails
  }

  lifecycle {
    ignore_changes = [time_period]
  }
}