package com.good.pet.hospital

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.view.Choreographer
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.Collections
import java.util.WeakHashMap

/**
 * Hides video_player SurfaceViews and waits for their native surfaces to be
 * destroyed before Flutter starts a route transition.
 */
internal class VideoSurfaceExitBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val handler = Handler(Looper.getMainLooper())
    private val hiddenSurfaces = Collections.newSetFromMap(
        WeakHashMap<SurfaceView, Boolean>(),
    )
    private var pendingExit: PendingExit? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "prepareForExit" -> prepareForExit(result)
                "restoreAfterCanceledExit" -> {
                    restoreAfterCanceledExit()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
        pendingExit?.cancel("activity_destroyed", "Activity 已销毁")
        pendingExit = null
        hiddenSurfaces.clear()
    }

    private fun prepareForExit(result: MethodChannel.Result) {
        val existing = pendingExit
        if (existing != null) {
            existing.addResult(result)
            return
        }

        val surfaces = mutableListOf<SurfaceView>()
        collectVideoSurfaces(activity.window.decorView, surfaces)
        if (surfaces.isEmpty()) {
            completeAfterFrames { result.success(exitPayload(0, false)) }
            return
        }

        PendingExit(surfaces, result).also {
            pendingExit = it
            it.start()
        }
    }

    private fun collectVideoSurfaces(view: View, result: MutableList<SurfaceView>) {
        if (view is SurfaceView && isVideoPlayerSurface(view) && view.isShown) {
            result.add(view)
        }
        if (view !is ViewGroup) return
        for (index in 0 until view.childCount) {
            collectVideoSurfaces(view.getChildAt(index), result)
        }
    }

    private fun isVideoPlayerSurface(view: SurfaceView): Boolean {
        val className = view.javaClass.name
        return className == SurfaceView::class.java.name ||
            className.startsWith("io.flutter.plugins.videoplayer.")
    }

    private fun restoreAfterCanceledExit() {
        pendingExit?.finish(timedOut = true)
        hiddenSurfaces.toList().forEach { surface ->
            if (surface.isAttachedToWindow) surface.visibility = View.VISIBLE
        }
        hiddenSurfaces.clear()
    }

    private fun completeAfterFrames(completion: () -> Unit) {
        var completed = false
        val completeOnce = Runnable {
            if (completed) return@Runnable
            completed = true
            completion()
        }
        handler.postDelayed(completeOnce, FRAME_FALLBACK_MILLIS)
        Choreographer.getInstance().postFrameCallback {
            Choreographer.getInstance().postFrameCallback {
                handler.removeCallbacks(completeOnce)
                completeOnce.run()
            }
        }
    }

    private fun exitPayload(hiddenCount: Int, timedOut: Boolean): Map<String, Any> {
        return mapOf("hiddenCount" to hiddenCount, "timedOut" to timedOut)
    }

    private inner class PendingExit(
        private val surfaces: List<SurfaceView>,
        result: MethodChannel.Result,
    ) : SurfaceHolder.Callback {
        private val results = mutableListOf(result)
        private val waitingHolders = surfaces.associateBy { it.holder }.toMutableMap()
        private var finishing = false
        private val timeout = Runnable { finish(timedOut = true) }

        fun addResult(result: MethodChannel.Result) {
            if (finishing) {
                result.success(exitPayload(surfaces.size, false))
            } else {
                results.add(result)
            }
        }

        fun start() {
            surfaces.forEach { surface ->
                surface.holder.addCallback(this)
                hiddenSurfaces.add(surface)
                surface.visibility = View.INVISIBLE
            }
            waitingHolders.entries.removeAll { !it.key.surface.isValid }
            handler.postDelayed(timeout, SURFACE_TIMEOUT_MILLIS)
            if (waitingHolders.isEmpty()) finish(timedOut = false)
        }

        override fun surfaceCreated(holder: SurfaceHolder) = Unit

        override fun surfaceChanged(
            holder: SurfaceHolder,
            format: Int,
            width: Int,
            height: Int,
        ) = Unit

        override fun surfaceDestroyed(holder: SurfaceHolder) {
            waitingHolders.remove(holder)
            if (waitingHolders.isEmpty()) finish(timedOut = false)
        }

        fun finish(timedOut: Boolean) {
            if (finishing) return
            finishing = true
            handler.removeCallbacks(timeout)
            surfaces.forEach { it.holder.removeCallback(this) }
            completeAfterFrames {
                val payload = exitPayload(surfaces.size, timedOut)
                results.forEach { it.success(payload) }
                if (pendingExit === this) pendingExit = null
            }
        }

        fun cancel(code: String, message: String) {
            if (finishing) return
            finishing = true
            handler.removeCallbacks(timeout)
            surfaces.forEach { it.holder.removeCallback(this) }
            results.forEach { it.error(code, message, null) }
        }
    }

    private companion object {
        const val CHANNEL_NAME = "com.good.pet.hospital/video_surface_exit"
        const val SURFACE_TIMEOUT_MILLIS = 280L
        const val FRAME_FALLBACK_MILLIS = 100L
    }
}
