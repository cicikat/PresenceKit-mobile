package com.presencekit.mobile.finance

import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal
import java.security.MessageDigest

/** Independently implemented, deliberately conservative rules. No notification text is stored. */
object PaymentParser {
    val packages = setOf("com.tencent.mm", "com.eg.android.AlipayGphone", "com.icbc", "com.ccb.start", "cmb.pb")
    fun hash(value: String): String = MessageDigest.getInstance("SHA-256").digest(value.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
    fun parse(pkg: String, title: String, text: String): JSONObject? {
        if (pkg !in packages) return null
        val raw = "$title $text".take(8192)
        if (Regex("验证码|优惠|立减|领券|红包活动|抽奖|广告|待支付|支付失败|付款失败|余额提醒").containsMatchIn(raw)) return null
        // Chat messages must not impersonate the payment system account.
        if (pkg == "com.tencent.mm" && title.trim() !in setOf("微信支付", "微信收款助手", "微信支付凭证")) return null
        if (!Regex("已支付|支付成功|付款成功|成功付款|退款成功|退款到账|收款成功|到账|消费人民币|扣款成功|转账成功|还款成功|红包已领取").containsMatchIn(raw)) return null
        val direction = when {
            raw.contains("退款") -> "refund"
            Regex("转账|还款|转入|转出|充值").containsMatchIn(raw) -> "transfer"
            raw.contains("红包") -> "unknown"
            Regex("收款|收入|到账").containsMatchIn(raw) -> "income"
            else -> "expense"
        }
        val tokens = Regex("(?:[￥¥]\\s*([0-9][0-9,.]*))|(?:([0-9][0-9,.]*)\\s*元)").findAll(raw)
            .map { it.groupValues[1].ifEmpty { it.groupValues[2] } }.distinct().toList()
        val amount = if (tokens.size == 1 && !raw.contains("…") && !raw.contains("...")) {
            tokens.single().takeIf { it.matches(Regex("(?:0|[1-9][0-9]{0,8})(?:\\.[0-9]{1,2})?")) }
                ?.let { runCatching { BigDecimal(it).movePointRight(2).longValueExact() }.getOrNull() }
                ?.takeIf { it > 0 }
        } else null
        val reasons = mutableListOf("rule_v1", "payment_signal", "user_confirmation_required")
        if (amount == null) reasons.add("amount_incomplete")
        // Only an explicitly labelled merchant is accepted; never copy arbitrary notification prose.
        val merchant = Regex("(?:商户|收款方)[：:]\\s*([^\\s，。；]{1,60})").find(raw)?.groupValues?.get(1)
            ?.takeIf { !Regex("[0-9]{6,}|验证码").containsMatchIn(it) }
        if (merchant == null) reasons.add("merchant_missing")
        return JSONObject().put("source_app", pkg).put("direction", direction)
            .put("amount_minor", amount ?: JSONObject.NULL).put("currency", if (amount != null) "CNY" else JSONObject.NULL)
            .put("merchant", merchant ?: JSONObject.NULL).put("category", JSONObject.NULL)
            .put("confidence", if (amount != null) "medium" else "low").put("reason_codes", JSONArray(reasons))
            .put("status", "candidate").put("linked_record_id", JSONObject.NULL)
    }
}
