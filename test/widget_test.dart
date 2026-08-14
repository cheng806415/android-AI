import 'package:ai_image_generator/models/generation_config.dart';
import 'package:ai_image_generator/models/generation_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('生成配置与任务持久化', () {
    test('生成配置可完整序列化和恢复', () {
      const config = GenerationConfig(
        prompt: '雨夜街道上的橘猫',
        model: 'gpt-image-2',
        size: '1920x1080',
        quality: 'high',
        count: 2,
        outputFormat: 'png',
        referenceImagePath: '/images/reference-1.png',
        referenceImagePaths: ['/images/reference-2.png'],
      );

      final restored = GenerationConfig.fromJson(config.toJson());

      expect(restored.prompt, config.prompt);
      expect(restored.model, config.model);
      expect(restored.size, config.size);
      expect(restored.count, 2);
      expect(restored.referenceImageCount, 2);
    });

    test('运行中的任务恢复后可重新排队', () {
      final now = DateTime.now();
      final task = GenerationTask(
        id: 'task-1',
        config: const GenerationConfig(prompt: '测试任务'),
        status: TaskStatus.running,
        attempt: 1,
        createdAt: now,
        updatedAt: now,
      );

      final restored = GenerationTask.fromMap(task.toMap());
      final queued = restored.copyWith(
        status: TaskStatus.queued,
        updatedAt: now,
      );

      expect(restored.status, TaskStatus.running);
      expect(queued.status, TaskStatus.queued);
      expect(queued.attempt, 1);
      expect(queued.config.prompt, '测试任务');
    });
  });
}
