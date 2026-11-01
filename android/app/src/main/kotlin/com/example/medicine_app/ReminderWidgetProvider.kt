package com.example.medicine_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Locale

class ReminderWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray, data: SharedPreferences) {
        val rows = listOf(R.id.widget_row_0, R.id.widget_row_1, R.id.widget_row_2)
        val titles = listOf(R.id.widget_title_0, R.id.widget_title_1, R.id.widget_title_2)
        val times = listOf(R.id.widget_time_0, R.id.widget_time_1, R.id.widget_time_2)
        val done = listOf(R.id.widget_done_0, R.id.widget_done_1, R.id.widget_done_2)
        val open = listOf(R.id.widget_open_0, R.id.widget_open_1, R.id.widget_open_2)
        val items = try { JSONArray(data.getString("reminders", "[]")) } catch (_: Exception) { JSONArray() }
        val copy = try { JSONObject(data.getString("widget_copy", "{}")) } catch (_: Exception) { JSONObject() }
        val scope = Uri.encode(data.getString("account_scope", "guest") ?: "guest")
        val locale = Locale(data.getString("widget_locale", "tr") ?: "tr")
        ids.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.reminder_widget)
            views.setTextViewText(R.id.widget_heading, copy.optString("widget_title", "Sıradaki hatırlatıcılar"))
            views.setTextViewText(R.id.widget_empty, copy.optString("widget_empty", "Bekleyen hatırlatıcı yok."))
            views.setContentDescription(R.id.widget_add, copy.optString("new_reminder", "Yeni hatırlatıcı"))
            done.forEach { views.setContentDescription(it, copy.optString("complete", "Tamamla")) }
            views.setOnClickPendingIntent(R.id.widget_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            views.setOnClickPendingIntent(R.id.widget_add, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("medapp-reminder://add?homeWidget")))
            views.setViewVisibility(R.id.widget_empty, if (items.length() == 0) View.VISIBLE else View.GONE)
            for (i in 0..2) {
                if (i >= items.length()) { views.setViewVisibility(rows[i], View.GONE); continue }
                val item = items.getJSONObject(i)
                val reminderId = Uri.encode(item.getString("id"))
                val rawDate = if (item.isNull("snoozedUntil")) item.getString("dueAt") else item.getString("snoozedUntil")
                val dateText = try {
                    val date = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).parse(rawDate)
                    SimpleDateFormat("d MMM · HH:mm", locale).format(date!!)
                } catch (_: Exception) { rawDate.take(16).replace('T', ' ') }
                views.setViewVisibility(rows[i], View.VISIBLE)
                views.setTextViewText(titles[i], item.getString("title"))
                views.setTextViewText(times[i], dateText)
                views.setOnClickPendingIntent(open[i], HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("medapp-reminder://detail?id=$reminderId&scope=$scope&homeWidget")))
                views.setOnClickPendingIntent(done[i], HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("medapp-reminder://done?id=$reminderId&scope=$scope")))
            }
            manager.updateAppWidget(id, views)
        }
    }
}
