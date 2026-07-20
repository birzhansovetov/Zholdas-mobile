package com.example.zholdas.data.local

import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class InMemoryTokenCacheTest {
    @Test
    fun `update exposes an atomic token pair`() {
        val cache = InMemoryTokenCache()
        cache.update("access", "refresh")
        assertEquals(TokenSnapshot("access", "refresh"), cache.snapshot())
    }

    @Test
    fun `clear removes both tokens`() {
        val cache = InMemoryTokenCache()
        cache.update("access", "refresh")
        cache.clear()
        assertNull(cache.snapshot())
    }

    @Test
    fun `late datastore initialization cannot restore tokens after sign out`() {
        val cache = InMemoryTokenCache()
        cache.clear()
        cache.initializeIfEmpty("stale-access", "stale-refresh")
        assertNull(cache.snapshot())
    }

    @Test
    fun `concurrent readers only observe complete token pairs`() {
        val cache = InMemoryTokenCache()
        val executor = Executors.newFixedThreadPool(6)
        val start = CountDownLatch(1)
        val done = CountDownLatch(6)
        val invalidReads = java.util.concurrent.atomic.AtomicInteger(0)

        repeat(3) { writer ->
            executor.execute {
                start.await()
                repeat(2_000) { index -> cache.update("a-$writer-$index", "r-$writer-$index") }
                done.countDown()
            }
        }
        repeat(3) {
            executor.execute {
                start.await()
                repeat(2_000) {
                    cache.snapshot()?.let { snapshot ->
                        if (snapshot.accessToken.removePrefix("a-") != snapshot.refreshToken.removePrefix("r-")) {
                            invalidReads.incrementAndGet()
                        }
                    }
                }
                done.countDown()
            }
        }

        start.countDown()
        done.await(5, TimeUnit.SECONDS)
        executor.shutdownNow()
        assertEquals(0, invalidReads.get())
    }
}
