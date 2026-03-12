# TSAN Verification Report: Atomic Snapshot

## 1. What data races did TSAN detect with refs?

To test for data races, I temporarily changed the snapshot implementation to use ref array instead of the `Atomic.t`. I then ran `test_manual.ml`. ThreadSanitizer (TSAN) caught **4 data races**. All the 4 dataraces caught during the execution of high contention test.

Here is what TSAN found:
* **Race 1:** Thread T4 (a writer thread) was writing to `0x7fffe51fff38` at the same time Thread T1 (a scanner thread) was reading from it.
* **Race 2:** Thread T4 was writing to `0x7fffe51fff08` at the same time Thread T1 was reading from it.
* **Race 3:** Thread T4 was writing to `0x7fffe51ffef8` at the same time Thread T1 was reading from it.
* **Race 4:** Thread T4 was writing to `0x7ffff6308db8` at the same time a different scanner, Thread T22, was reading from it.


## 2. Why does the atomic implementation avoid races?

`Atomic` inserts memory fences and disables unsafe compiler optimisations that break sequential consistency.
Memory fence enforces an ordering constraint between the instructions before and after
the fence. and also Flush write buffer and bring caches up to date.
Because of this atomic implementation avoid data races.

## 3. TSAN Outputs

## A. Output with Non-Atomic Implementation (Data Races Detected)

```text
Test 1: Sequential operations
 ✓ Passed : Actual array (10 , 20, 30, 40) ,  Expected array (10 , 20, 30, 40)
Test 2: Concurrent updates, single scanner
 ✓ Passed : Final values (100 , 1100, 2100, 3100)
Test 3: Multiple concurrent scanners
 ✓ Passed
Test 4: High contention stress test
==================
WARNING: ThreadSanitizer: data race (pid=491026)
  Write of size 8 at 0x7fffe51fff38 by thread T4 (mutexes: write M89):
    #0 caml_modify runtime/memory.c:225 (test_manual.exe+0xd43a1)
    #1 camlSnapshot.update_334 <null> (test_manual.exe+0x50bbd)
    #2 camlDune__exe__Test_manual.writer_helper_472 <null> (test_manual.exe+0x50549)
    #3 camlStdlib__Domain.body_757 <null> (test_manual.exe+0x889bf)
    #4 caml_start_program <null> (test_manual.exe+0xf2def)
    #5 caml_callback_exn runtime/callback.c:206 (test_manual.exe+0xac963)
    #6 caml_callback_res runtime/callback.c:321 (test_manual.exe+0xad5f2)
    #7 domain_thread_func runtime/domain.c:1273 (test_manual.exe+0xb348d)

  Previous read of size 8 at 0x7fffe51fff38 by thread T1 (mutexes: write M94):
    #0 camlSnapshot.fun_365 <null> (test_manual.exe+0x50cb0)
    #1 camlStdlib__Array.init_295 <null> (test_manual.exe+0x6d4e4)
    #2 camlSnapshot.try_snapshot_346 <null> (test_manual.exe+0x50d83)
    #3 camlDune__exe__Test_manual.scanner_helper_477 <null> (test_manual.exe+0x50683)
    #4 camlStdlib__Domain.body_757 <null> (test_manual.exe+0x889bf)
    #5 caml_start_program <null> (test_manual.exe+0xf2def)
    #6 caml_callback_exn runtime/callback.c:206 (test_manual.exe+0xac963)
    #7 caml_callback_res runtime/callback.c:321 (test_manual.exe+0xad5f2)
    #8 domain_thread_func runtime/domain.c:1273 (test_manual.exe+0xb348d)

  Mutex M89 (0x7bb4000002c0) created at:
    #0 pthread_mutex_init ../../../../src/libsanitizer/tsan/tsan_interceptors_posix.cpp:1227 (libtsan.so.0+0x4bee1)
    #1 caml_plat_mutex_init runtime/platform.c:59 (test_manual.exe+0xdef8a)
    #2 caml_init_domains runtime/domain.c:996 (test_manual.exe+0xb12ea)
    #3 caml_init_gc runtime/gc_ctrl.c:359 (test_manual.exe+0xbf1b2)
    #4 caml_startup_common runtime/startup_nat.c:106 (test_manual.exe+0xf2477)
    #5 caml_startup_common runtime/startup_nat.c:86 (test_manual.exe+0xf2477)
    #6 caml_startup_exn runtime/startup_nat.c:134 (test_manual.exe+0xf263b)
    #7 caml_startup runtime/startup_nat.c:139 (test_manual.exe+0xf263b)
    #8 caml_main runtime/startup_nat.c:146 (test_manual.exe+0xf263b)
    #9 main runtime/main.c:37 (test_manual.exe+0x4bc09)

  Mutex M94 (0x7bb4000003d0) created at:
    #0 pthread_mutex_init ../../../../src/libsanitizer/tsan/tsan_interceptors_posix.cpp:1227 (libtsan.so.0+0x4bee1)
    #1 caml_plat_mutex_init runtime/platform.c:59 (test_manual.exe+0xdef8a)
    #2 caml_init_domains runtime/domain.c:996 (test_manual.exe+0xb12ea)
    #3 caml_init_gc runtime/gc_ctrl.c:359 (test_manual.exe+0xbf1b2)
    #4 caml_startup_common runtime/startup_nat.c:106 (test_manual.exe+0xf2477)
    #5 caml_startup_common runtime/startup_nat.c:86 (test_manual.exe+0xf2477)
    #6 caml_startup_exn runtime/startup_nat.c:134 (test_manual.exe+0xf263b)
    #7 caml_startup runtime/startup_nat.c:139 (test_manual.exe+0xf263b)
    #8 caml_main runtime/startup_nat.c:146 (test_manual.exe+0xf263b)
    #9 main runtime/main.c:37 (test_manual.exe+0x4bc09)

  Thread T4 (tid=491062, running) created by main thread at:
    #0 pthread_create ../../../../src/libsanitizer/tsan/tsan_interceptors_posix.cpp:969 (libtsan.so.0+0x605b8)
    #1 caml_domain_spawn runtime/domain.c:1347 (test_manual.exe+0xb25c6)
    #2 caml_c_call <null> (test_manual.exe+0xf2ccb)
    #3 camlStdlib__Domain.spawn_752 <null> (test_manual.exe+0x888d6)
    #4 camlDune__exe__Test_manual.test_high_contention_468 <null> (test_manual.exe+0x501fb)
    #5 camlDune__exe__Test_manual.entry <null> (test_manual.exe+0x509ac)
    #6 caml_program <null> (test_manual.exe+0x4c0c9)
    #7 caml_start_program <null> (test_manual.exe+0xf2def)
    #8 caml_startup_common runtime/startup_nat.c:127 (test_manual.exe+0xf2590)
    #9 caml_startup_common runtime/startup_nat.c:86 (test_manual.exe+0xf2590)
    #10 caml_startup_exn runtime/startup_nat.c:134 (test_manual.exe+0xf263b)
    #11 caml_startup runtime/startup_nat.c:139 (test_manual.exe+0xf263b)
    #12 caml_main runtime/startup_nat.c:146 (test_manual.exe+0xf263b)
    #13 main runtime/main.c:37 (test_manual.exe+0x4bc09)

  Thread T1 (tid=491060, running) created by main thread at:
    #0 pthread_create ../../../../src/libsanitizer/tsan/tsan_interceptors_posix.cpp:969 (libtsan.so.0+0x605b8)
    #1 caml_domain_spawn runtime/domain.c:1347 (test_manual.exe+0xb25c6)
    #2 caml_c_call <null> (test_manual.exe+0xf2ccb)
    #3 camlStdlib__Domain.spawn_752 <null> (test_manual.exe+0x888d6)
    #4 camlDune__exe__Test_manual.test_high_contention_468 <null> (test_manual.exe+0x501ad)
    #5 camlDune__exe__Test_manual.entry <null> (test_manual.exe+0x509ac)
    #6 caml_program <null> (test_manual.exe+0x4c0c9)
    #7 caml_start_program <null> (test_manual.exe+0xf2def)
    #8 caml_startup_common runtime/startup_nat.c:127 (test_manual.exe+0xf2590)
    #9 caml_startup_common runtime/startup_nat.c:86 (test_manual.exe+0xf2590)
    #10 caml_startup_exn runtime/startup_nat.c:134 (test_manual.exe+0xf263b)
    #11 caml_startup runtime/startup_nat.c:139 (test_manual.exe+0xf263b)
    #12 caml_main runtime/startup_nat.c:146 (test_manual.exe+0xf263b)
    #13 main runtime/main.c:37 (test_manual.exe+0x4bc09)

SUMMARY: ThreadSanitizer: data race runtime/memory.c:225 in caml_modify
==================
==================
WARNING: ThreadSanitizer: data race (pid=491026)
  Write of size 8 at 0x7fffe51fff08 by thread T4 (mutexes: write M89):
    #0 caml_modify runtime/memory.c:225 (test_manual.exe+0xd43a1)
    #1 camlSnapshot.update_334 <null> (test_manual.exe+0x50bbd)
    #2 camlDune__exe__Test_manual.writer_helper_472 <null> (test_manual.exe+0x5057a)
    #3 camlStdlib__Domain.body_757 <null> (test_manual.exe+0x889bf)
    #4 caml_start_program <null> (test_manual.exe+0xf2def)
    #5 caml_callback_exn runtime/callback.c:206 (test_manual.exe+0xac963)
    #6 caml_callback_res runtime/callback.c:321 (test_manual.exe+0xad5f2)
    #7 domain_thread_func runtime/domain.c:1273 (test_manual.exe+0xb348d)

  Previous read of size 8 at 0x7fffe51fff08 by thread T1:
    [failed to restore the stack]

  Mutex M89 (0x7bb4000002c0) created at:
    #0 pthread_mutex_init ../../../../src/libsanitizer/tsan/tsan_interceptors_posix.cpp:1227 (libtsan.so.0+0x4bee1)
    #1 caml_plat_mutex_init runtime/platform.c:59 (test_manual.exe+0xdef8a)
    #2 caml_init_domains runtime/domain.c:996 (test_manual.exe+0xb12ea)
    #3 caml_init_gc runtime/gc_ctrl.c:359 (test_manual.exe+0xbf1b2)
    #4 caml_startup_common runtime/startup_nat.c:106 (test_manual.exe+0xf2477)
    #5 caml_startup_common runtime/startup_nat.c:86 (test_manual.exe+0xf2477)
    #6 caml_startup_exn runtime/startup_nat.c:134 (test_manual.exe+0xf263b)
    #7 caml_startup runtime/startup_nat.c:139 (test_manual.exe+0xf263b)
    #8 caml_main runtime/startup_nat.c:146 (test_manual.exe+0xf263b)
    #9 main runtime/main.c:37 (test_manual.exe+0x4bc09)

  Thread T4 (tid=491062, running) created by main thread at:
    #0 pthread_create ../../../../src/libsanitizer/tsan/tsan_interceptors_posix.cpp:969 (libtsan.so.0+0x605b8)
    #1 caml_domain_spawn runtime/domain.c:1347 (test_manual.exe+0xb25c6)
    #2 caml_c_call <null> (test_manual.exe+0xf2ccb)
    #3 camlStdlib__Domain.spawn_752 <null> (test_manual.exe+0x888d6)
    #4 camlDune__exe__Test_manual.test_high_contention_468 <null> (test_manual.exe+0x501fb)
    #5 camlDune__exe__Test_manual.entry <null> (test_manual.exe+0x509ac)
    #6 caml_program <null> (test_manual.exe+0x4c0c9)
    #7 caml_start_program <null> (test_manual.exe+0xf2def)
    #8 caml_startup_common runtime/startup_nat.c:127 (test_manual.exe+0xf2590)
    #9 caml_startup_common runtime/startup_nat.c:86 (test_manual.exe+0xf2590)
    #10 caml_startup_exn runtime/startup_nat.c:134 (test_manual.exe+0xf263b)
    #11 caml_startup runtime/startup_nat.c:139 (test_manual.exe+0xf263b)
    #12 caml_main runtime/startup_nat.c:146 (test_manual.exe+0xf263b)
    #13 main runtime/main.c:37 (test_manual.exe+0x4bc09)

  Thread T1 (tid=491060, running) created by main thread at:
    #0 pthread_create ../../../../src/libsanitizer/tsan/tsan_interceptors_posix.cpp:969 (libtsan.so.0+0x605b8)
    #1 caml_domain_spawn runtime/domain.c:1347 (test_manual.exe+0xb25c6)
    #2 caml_c_call <null> (test_manual.exe+0xf2ccb)
    #3 camlStdlib__Domain.spawn_752 <null> (test_manual.exe+0x888d6)
    #4 camlDune__exe__Test_manual.test_high_contention_468 <null> (test_manual.exe+0x501ad)
    #5 camlDune__exe__Test_manual.entry <null> (test_manual.exe+0x509ac)
    #6 caml_program <null> (test_manual.exe+0x4c0c9)
    #7 caml_start_program <null> (test_manual.exe+0xf2def)
    #8 caml_startup_common runtime/startup_nat.c:127 (test_manual.exe+0xf2590)
    #9 caml_startup_common runtime/startup_nat.c:86 (test_manual.exe+0xf2590)
    #10 caml_startup_exn runtime/startup_nat.c:134 (test_manual.exe+0xf263b)
    #11 caml_startup runtime/startup_nat.c:139 (test_manual.exe+0xf263b)
    #12 caml_main runtime/startup_nat.c:146 (test_manual.exe+0xf263b)
    #13 main runtime/main.c:37 (test_manual.exe+0x4bc09)

SUMMARY: ThreadSanitizer: data race runtime/memory.c:225 in caml_modify
==================
==================
WARNING: ThreadSanitizer: data race (pid=491026)
  Write of size 8 at 0x7fffe51ffef8 by thread T4 (mutexes: write M89):
    #0 caml_modify runtime/memory.c:225 (test_manual.exe+0xd43a1)
    #1 camlSnapshot.update_334 <null> (test_manual.exe+0x50bbd)
    #2 camlDune__exe__Test_manual.writer_helper_472 <null> (test_manual.exe+0x505ab)
    #3 camlStdlib__Domain.body_757 <null> (test_manual.exe+0x889bf)
    #4 caml_start_program <null> (test_manual.exe+0xf2def)
    #5 caml_callback_exn runtime/callback.c:206 (test_manual.exe+0xac963)
    #6 caml_callback_res runtime/callback.c:321 (test_manual.exe+0xad5f2)
    #7 domain_thread_func runtime/domain.c:1273 (test_manual.exe+0xb348d)

  Previous read of size 8 at 0x7fffe51ffef8 by thread T1:
    [failed to restore the stack]

  Mutex M89 (0x7bb4000002c0) created at:
    #0 pthread_mutex_init ../../../../src/libsanitizer/tsan/tsan_interceptors_posix.cpp:1227 (libtsan.so.0+0x4bee1)
    #1 caml_plat_mutex_init runtime/platform.c:59 (test_manual.exe+0xdef8a)
    #2 caml_init_domains runtime/domain.c:996 (test_manual.exe+0xb12ea)
    #3 caml_init_gc runtime/gc_ctrl.c:359 (test_manual.exe+0xbf1b2)
    #4 caml_startup_common runtime/startup_nat.c:106 (test_manual.exe+0xf2477)
    #5 caml_startup_common runtime/startup_nat.c:86 (test_manual.exe+0xf2477)
    #6 caml_startup_exn runtime/startup_nat.c:134 (test_manual.exe+0xf263b)
    #7 caml_startup runtime/startup_nat.c:139 (test_manual.exe+0xf263b)
    #8 caml_main runtime/startup_nat.c:146 (test_manual.exe+0xf263b)
    #9 main runtime/main.c:37 (test_manual.exe+0x4bc09)

  Thread T4 (tid=491062, running) created by main thread at:
    #0 pthread_create ../../../../src/libsanitizer/tsan/tsan_interceptors_posix.cpp:969 (libtsan.so.0+0x605b8)
    #1 caml_domain_spawn runtime/domain.c:1347 (test_manual.exe+0xb25c6)
    #2 caml_c_call <null> (test_manual.exe+0xf2ccb)
    #3 camlStdlib__Domain.spawn_752 <null> (test_manual.exe+0x888d6)
    #4 camlDune__exe__Test_manual.test_high_contention_468 <null> (test_manual.exe+0x501fb)
    #5 camlDune__exe__Test_manual.entry <null> (test_manual.exe+0x509ac)
    #6 caml_program <null> (test_manual.exe+0x4c0c9)
    #7 caml_start_program <null> (test_manual.exe+0xf2def)
    #8 caml_startup_common runtime/startup_nat.c:127 (test_manual.exe+0xf2590)
    #9 caml_startup_common runtime/startup_nat.c:86 (test_manual.exe+0xf2590)
    #10 caml_startup_exn runtime/startup_nat.c:134 (test_manual.exe+0xf263b)
    #11 caml_startup runtime/startup_nat.c:139 (test_manual.exe+0xf263b)
    #12 caml_main runtime/startup_nat.c:146 (test_manual.exe+0xf263b)
    #13 main runtime/main.c:37 (test_manual.exe+0x4bc09)

  Thread T1 (tid=491060, running) created by main thread at:
    #0 pthread_create ../../../../src/libsanitizer/tsan/tsan_interceptors_posix.cpp:969 (libtsan.so.0+0x605b8)
    #1 caml_domain_spawn runtime/domain.c:1347 (test_manual.exe+0xb25c6)
    #2 caml_c_call <null> (test_manual.exe+0xf2ccb)
    #3 camlStdlib__Domain.spawn_752 <null> (test_manual.exe+0x888d6)
    #4 camlDune__exe__Test_manual.test_high_contention_468 <null> (test_manual.exe+0x501ad)
    #5 camlDune__exe__Test_manual.entry <null> (test_manual.exe+0x509ac)
    #6 caml_program <null> (test_manual.exe+0x4c0c9)
    #7 caml_start_program <null> (test_manual.exe+0xf2def)
    #8 caml_startup_common runtime/startup_nat.c:127 (test_manual.exe+0xf2590)
    #9 caml_startup_common runtime/startup_nat.c:86 (test_manual.exe+0xf2590)
    #10 caml_startup_exn runtime/startup_nat.c:134 (test_manual.exe+0xf263b)
    #11 caml_startup runtime/startup_nat.c:139 (test_manual.exe+0xf263b)
    #12 caml_main runtime/startup_nat.c:146 (test_manual.exe+0xf263b)
    #13 main runtime/main.c:37 (test_manual.exe+0x4bc09)

SUMMARY: ThreadSanitizer: data race runtime/memory.c:225 in caml_modify
==================
==================
WARNING: ThreadSanitizer: data race (pid=491026)
  Write of size 8 at 0x7ffff6308db8 by thread T4 (mutexes: write M89):
    #0 caml_modify runtime/memory.c:225 (test_manual.exe+0xd43a1)
    #1 camlSnapshot.update_334 <null> (test_manual.exe+0x50bbd)
    #2 camlDune__exe__Test_manual.writer_helper_472 <null> (test_manual.exe+0x5057a)
    #3 camlStdlib__Domain.body_757 <null> (test_manual.exe+0x889bf)
    #4 caml_start_program <null> (test_manual.exe+0xf2def)
    #5 caml_callback_exn runtime/callback.c:206 (test_manual.exe+0xac963)
    #6 caml_callback_res runtime/callback.c:321 (test_manual.exe+0xad5f2)
    #7 domain_thread_func runtime/domain.c:1273 (test_manual.exe+0xb348d)

  Previous read of size 8 at 0x7ffff6308db8 by thread T22 (mutexes: write M84):
    #0 camlSnapshot.fun_365 <null> (test_manual.exe+0x50cb0)
    #1 camlStdlib__Array.init_295 <null> (test_manual.exe+0x6d542)
    #2 camlSnapshot.try_snapshot_346 <null> (test_manual.exe+0x50d83)
    #3 camlDune__exe__Test_manual.scanner_helper_477 <null> (test_manual.exe+0x50683)
    #4 camlStdlib__Domain.body_757 <null> (test_manual.exe+0x889bf)
    #5 caml_start_program <null> (test_manual.exe+0xf2def)
    #6 caml_callback_exn runtime/callback.c:206 (test_manual.exe+0xac963)
    #7 caml_callback_res runtime/callback.c:321 (test_manual.exe+0xad5f2)
    #8 domain_thread_func runtime/domain.c:1273 (test_manual.exe+0xb348d)

  Mutex M89 (0x7bb4000002c0) created at:
    #0 pthread_mutex_init ../../../../src/libsanitizer/tsan/tsan_interceptors_posix.cpp:1227 (libtsan.so.0+0x4bee1)
    #1 caml_plat_mutex_init runtime/platform.c:59 (test_manual.exe+0xdef8a)
    #2 caml_init_domains runtime/domain.c:996 (test_manual.exe+0xb12ea)
    #3 caml_init_gc runtime/gc_ctrl.c:359 (test_manual.exe+0xbf1b2)
    #4 caml_startup_common runtime/startup_nat.c:106 (test_manual.exe+0xf2477)
    #5 caml_startup_common runtime/startup_nat.c:86 (test_manual.exe+0xf2477)
    #6 caml_startup_exn runtime/startup_nat.c:134 (test_manual.exe+0xf263b)
    #7 caml_startup runtime/startup_nat.c:139 (test_manual.exe+0xf263b)
    #8 caml_main runtime/startup_nat.c:146 (test_manual.exe+0xf263b)
    #9 main runtime/main.c:37 (test_manual.exe+0x4bc09)

  Mutex M84 (0x7bb4000001b0) created at:
    #0 pthread_mutex_init ../../../../src/libsanitizer/tsan/tsan_interceptors_posix.cpp:1227 (libtsan.so.0+0x4bee1)
    #1 caml_plat_mutex_init runtime/platform.c:59 (test_manual.exe+0xdef8a)
    #2 caml_init_domains runtime/domain.c:996 (test_manual.exe+0xb12ea)
    #3 caml_init_gc runtime/gc_ctrl.c:359 (test_manual.exe+0xbf1b2)
    #4 caml_startup_common runtime/startup_nat.c:106 (test_manual.exe+0xf2477)
    #5 caml_startup_common runtime/startup_nat.c:86 (test_manual.exe+0xf2477)
    #6 caml_startup_exn runtime/startup_nat.c:134 (test_manual.exe+0xf263b)
    #7 caml_startup runtime/startup_nat.c:139 (test_manual.exe+0xf263b)
    #8 caml_main runtime/startup_nat.c:146 (test_manual.exe+0xf263b)
    #9 main runtime/main.c:37 (test_manual.exe+0x4bc09)

  Thread T4 (tid=491062, running) created by main thread at:
    #0 pthread_create ../../../../src/libsanitizer/tsan/tsan_interceptors_posix.cpp:969 (libtsan.so.0+0x605b8)
    #1 caml_domain_spawn runtime/domain.c:1347 (test_manual.exe+0xb25c6)
    #2 caml_c_call <null> (test_manual.exe+0xf2ccb)
    #3 camlStdlib__Domain.spawn_752 <null> (test_manual.exe+0x888d6)
    #4 camlDune__exe__Test_manual.test_high_contention_468 <null> (test_manual.exe+0x501fb)
    #5 camlDune__exe__Test_manual.entry <null> (test_manual.exe+0x509ac)
    #6 caml_program <null> (test_manual.exe+0x4c0c9)
    #7 caml_start_program <null> (test_manual.exe+0xf2def)
    #8 caml_startup_common runtime/startup_nat.c:127 (test_manual.exe+0xf2590)
    #9 caml_startup_common runtime/startup_nat.c:86 (test_manual.exe+0xf2590)
    #10 caml_startup_exn runtime/startup_nat.c:134 (test_manual.exe+0xf263b)
    #11 caml_startup runtime/startup_nat.c:139 (test_manual.exe+0xf263b)
    #12 caml_main runtime/startup_nat.c:146 (test_manual.exe+0xf263b)
    #13 main runtime/main.c:37 (test_manual.exe+0x4bc09)

  Thread T22 (tid=491064, running) created by main thread at:
    #0 pthread_create ../../../../src/libsanitizer/tsan/tsan_interceptors_posix.cpp:969 (libtsan.so.0+0x605b8)
    #1 caml_domain_spawn runtime/domain.c:1347 (test_manual.exe+0xb25c6)
    #2 caml_c_call <null> (test_manual.exe+0xf2ccb)
    #3 camlStdlib__Domain.spawn_752 <null> (test_manual.exe+0x888d6)
    #4 camlDune__exe__Test_manual.test_high_contention_468 <null> (test_manual.exe+0x50248)
    #5 camlDune__exe__Test_manual.entry <null> (test_manual.exe+0x509ac)
    #6 caml_program <null> (test_manual.exe+0x4c0c9)
    #7 caml_start_program <null> (test_manual.exe+0xf2def)
    #8 caml_startup_common runtime/startup_nat.c:127 (test_manual.exe+0xf2590)
    #9 caml_startup_common runtime/startup_nat.c:86 (test_manual.exe+0xf2590)
    #10 caml_startup_exn runtime/startup_nat.c:134 (test_manual.exe+0xf263b)
    #11 caml_startup runtime/startup_nat.c:139 (test_manual.exe+0xf263b)
    #12 caml_main runtime/startup_nat.c:146 (test_manual.exe+0xf263b)
    #13 main runtime/main.c:37 (test_manual.exe+0x4bc09)

SUMMARY: ThreadSanitizer: data race runtime/memory.c:225 in caml_modify
==================
 ✓ Passed
 All manual tests passed!
ThreadSanitizer: reported 4 warnings

```



## B. Output with Atomic Implementation (No Data Races)

```text

Test 1: Sequential operations
 ✓ Passed : Actual array (10 , 20, 30, 40) ,  Expected array (10 , 20, 30, 40)
Test 2: Concurrent updates, single scanner
 ✓ Passed : Final values (100 , 1100, 2100, 3100)
Test 3: Multiple concurrent scanners
 ✓ Passed
Test 4: High contention stress test
 ✓ Passed
 All manual tests passed!
 ```