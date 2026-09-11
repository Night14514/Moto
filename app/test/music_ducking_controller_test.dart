import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mototalk/services/music_ducking_controller.dart';

void main() {
  group('MusicDuckingController', () {
    test('activity on → onDuckRequested exactly once', () {
      fakeAsync((async) {
        var ducks = 0;
        var resumes = 0;
        final c = MusicDuckingController(
          onDuckRequested: () async => ducks++,
          onResumeRequested: () async => resumes++,
        );

        c.onVoiceActivityChanged(true);
        async.flushMicrotasks();

        expect(ducks, 1);
        expect(resumes, 0);
        expect(c.duckActive, isTrue);
        c.dispose();
      });
    });

    test('silence then speak again before 5s → no resume, no second duck', () {
      fakeAsync((async) {
        var ducks = 0;
        var resumes = 0;
        final c = MusicDuckingController(
          onDuckRequested: () async => ducks++,
          onResumeRequested: () async => resumes++,
        );

        c.onVoiceActivityChanged(true);
        async.flushMicrotasks();
        c.onVoiceActivityChanged(false);
        async.elapse(const Duration(seconds: 3));
        c.onVoiceActivityChanged(true);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));

        expect(ducks, 1);
        expect(resumes, 0);
        expect(c.duckActive, isTrue);
        c.dispose();
      });
    });

    test('silence for 5s → onResumeRequested once at ~5.0s', () {
      fakeAsync((async) {
        var ducks = 0;
        var resumes = 0;
        final c = MusicDuckingController(
          onDuckRequested: () async => ducks++,
          onResumeRequested: () async => resumes++,
        );

        c.onVoiceActivityChanged(true);
        async.flushMicrotasks();
        c.onVoiceActivityChanged(false);

        async.elapse(const Duration(milliseconds: 4999));
        expect(resumes, 0);
        expect(c.duckActive, isTrue);

        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();

        expect(ducks, 1);
        expect(resumes, 1);
        expect(c.duckActive, isFalse);
        c.dispose();
      });
    });

    test('forceResumeNow mid-countdown resumes once and cancels timer', () {
      fakeAsync((async) {
        var ducks = 0;
        var resumes = 0;
        final c = MusicDuckingController(
          onDuckRequested: () async => ducks++,
          onResumeRequested: () async => resumes++,
        );

        c.onVoiceActivityChanged(true);
        async.flushMicrotasks();
        c.onVoiceActivityChanged(false);
        async.elapse(const Duration(seconds: 2));

        c.forceResumeNow();
        async.flushMicrotasks();
        expect(resumes, 1);
        expect(c.duckActive, isFalse);

        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();
        expect(resumes, 1);
        expect(ducks, 1);
        c.dispose();
      });
    });

    test('rapid 20 toggles at 100ms → single duck, no resume until 5s quiet',
        () {
      fakeAsync((async) {
        var ducks = 0;
        var resumes = 0;
        final c = MusicDuckingController(
          onDuckRequested: () async => ducks++,
          onResumeRequested: () async => resumes++,
        );

        for (var i = 0; i < 20; i++) {
          c.onVoiceActivityChanged(i.isEven);
          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();
        }
        // Last iteration i=19 → active=false; duck still held.
        expect(ducks, 1);
        expect(resumes, 0);
        expect(c.duckActive, isTrue);

        async.elapse(MusicDuckingController.resumeDelay);
        async.flushMicrotasks();
        expect(resumes, 1);
        expect(c.duckActive, isFalse);
        c.dispose();
      });
    });
  });
}
