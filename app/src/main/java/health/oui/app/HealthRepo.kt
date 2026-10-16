package health.oui.app

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord
import androidx.health.connect.client.records.OxygenSaturationRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.RestingHeartRateRecord
import androidx.health.connect.client.records.SkinTemperatureRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Instant
import java.time.temporal.ChronoUnit
import kotlin.reflect.KClass

/**
 * Reads the watch's health data from Health Connect. Finding 0004 confirmed Samsung Health writes
 * this full set to Health Connect on ANY phone, so this needs no un-gating — it is the official
 * API reading your own data.
 */
class HealthRepo(context: Context) {

    private val client by lazy { HealthConnectClient.getOrCreate(context) }

    /** The watch-relevant record types we read. Keep in sync with the manifest uses-permissions. */
    val recordTypes: List<KClass<out Record>> = listOf(
        HeartRateRecord::class,
        RestingHeartRateRecord::class,
        HeartRateVariabilityRmssdRecord::class,
        OxygenSaturationRecord::class,
        SkinTemperatureRecord::class,
        StepsRecord::class,
        TotalCaloriesBurnedRecord::class,
        SleepSessionRecord::class,
        ExerciseSessionRecord::class,
    )

    val readPermissions: Set<String> =
        recordTypes.map { HealthPermission.getReadPermission(it) }.toSet()

    companion object {
        fun sdkAvailable(context: Context): Boolean =
            HealthConnectClient.getSdkStatus(context) == HealthConnectClient.SDK_AVAILABLE
    }

    suspend fun grantedPermissions(): Set<String> =
        client.permissionController.getGrantedPermissions()

    /** One-line summary per record type over the last [hours] hours. */
    suspend fun summarize(hours: Long = 24): String {
        val range = TimeRangeFilter.between(
            Instant.now().minus(hours, ChronoUnit.HOURS), Instant.now()
        )
        val sb = StringBuilder("Last ${hours}h from Health Connect:\n\n")
        for (type in recordTypes) {
            sb.append(summarizeType(type, range)).append('\n')
        }
        return sb.toString()
    }

    private suspend fun <T : Record> summarizeType(type: KClass<T>, range: TimeRangeFilter): String {
        return try {
            val records = client.readRecords(ReadRecordsRequest(type, range)).records
            val latest = records.lastOrNull()?.let { latestValue(it) }.orEmpty()
            "• ${type.simpleName?.removeSuffix("Record")}: ${records.size} record(s) $latest"
        } catch (e: Exception) {
            "• ${type.simpleName?.removeSuffix("Record")}: (not granted / unavailable)"
        }
    }

    private fun latestValue(r: Record): String = when (r) {
        is HeartRateRecord -> r.samples.lastOrNull()?.let { "→ ${it.beatsPerMinute} bpm" }.orEmpty()
        is RestingHeartRateRecord -> "→ ${r.beatsPerMinute} bpm resting"
        is HeartRateVariabilityRmssdRecord -> "→ ${r.heartRateVariabilityMillis} ms"
        is OxygenSaturationRecord -> "→ ${r.percentage.value}% SpO2"
        is SkinTemperatureRecord -> "→ skin temp sample set"
        is StepsRecord -> "→ ${r.count} steps"
        is TotalCaloriesBurnedRecord -> "→ ${r.energy.inKilocalories.toInt()} kcal"
        is SleepSessionRecord -> "→ ${r.startTime}…${r.endTime}"
        is ExerciseSessionRecord -> "→ type ${r.exerciseType}"
        else -> ""
    }
}
