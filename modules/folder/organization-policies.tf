/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

# tfdoc:file:description Folder-level organization policies.

locals {
  org_policies = {
    for k, v in var.org_policies :
    k => merge(v, {
      name   = "${local.folder.name}/policies/${k}"
      parent = local.folder.name

      is_boolean_policy = v.allow == null && v.deny == null
      has_values = (
        length(coalesce(try(v.allow.values, []), [])) > 0 ||
        length(coalesce(try(v.deny.values, []), [])) > 0
      )
      rules = [
        for r in v.rules :
        merge(r, {
          has_values = (
            length(coalesce(try(r.allow.values, []), [])) > 0 ||
            length(coalesce(try(r.deny.values, []), [])) > 0
          )
        })
      ]
    })
  }
}

resource "google_org_policy_policy" "default" {
  for_each = local.org_policies
  name     = each.value.name
  parent   = each.value.parent

  spec {
    inherit_from_parent = each.value.inherit_from_parent
    reset               = each.value.reset

    rules {
      allow_all = try(each.value.allow.all, null) == true ? "TRUE" : null
      deny_all  = try(each.value.deny.all, null) == true ? "TRUE" : null
      enforce = (
        each.value.is_boolean_policy && each.value.enforce != null
        ? upper(tostring(each.value.enforce))
        : null
      )
      dynamic "values" {
        for_each = each.value.has_values ? [1] : []
        content {
          allowed_values = try(each.value.allow.values, null)
          denied_values  = try(each.value.deny.values, null)
        }
      }
    }

    dynamic "rules" {
      for_each = each.value.rules
      iterator = rule
      content {
        allow_all = try(rule.value.allow.all, false) == true ? "TRUE" : null
        deny_all  = try(rule.value.deny.all, false) == true ? "TRUE" : null
        enforce = (
          each.value.is_boolean_policy && rule.value.enforce != null
          ? upper(tostring(rule.value.enforce))
          : null
        )
        condition {
          description = rule.value.condition.description
          expression  = rule.value.condition.expression
          location    = rule.value.condition.location
          title       = rule.value.condition.title
        }
        dynamic "values" {
          for_each = rule.value.has_values ? [1] : []
          content {
            allowed_values = try(rule.value.allow.values, null)
            denied_values  = try(rule.value.deny.values, null)
          }
        }
      }
    }
  }
}
