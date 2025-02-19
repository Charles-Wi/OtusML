Otus ML Pro 2024: Домашняя работа — Что день грядущий нам готовит? Построение прогноза временного ряда с использованием изученных методов
=================

1. [1.EDA.ipynb](1.EDA.ipynb) «Проводим базовый EDA, вам понадобятся только 4 столбца датасета - traffic_volume (наша целевая переменная), date_time, holiday (является ли день некоторым праздником) и temp (температура воздуха).» Также: «…дубликаты удаляем, а временные интервалы выравниваем и заполняем пропуски при помощи линейной интерполяции…».<br />
В notebook присутствует график, но была проблема с его отображением через github веб-интерфейс. Поэтому график приложен и в виде отдельного файла: <a href="1.EDA.png">1.EDA.png</a>.
2. [2.Split_train_test.ipynb](2.Split_train_test.ipynb) Разделить набор данных на на train и test (2 недели).
3. [3.Modeling.ipynb](3.Modeling.ipynb) Моделирование: простая статистическая модель, SARMA, трансформеры, выводы, таблицы и сравнительные графики (в конце notebook).<br />
3.2. [3.2.Fine-tune_render_train_data.ipynb](3.2.Fine-tune_render_train_data.ipynb) Дополнительно, выполним fine-tune трансформерной модели путем добавления корректирующей «головы» FNN. Генерируем тренировочный набор данных для FNN.<br />
3.3. [3.3.Fine-tune_train_and_test_fnn.ipynb](3.3.Fine-tune_train_and_test_fnn.ipynb) Тренировка корректирующей FNN и применение комбинированной модели. Результаты добавлены в [3.Modeling.ipynb](3.Modeling.ipynb).<br /><br />
В notebook "3.Modeling.ipynb" присутствует график, но была проблема с его отображением через github веб-интерфейс. Поэтому график приложен и в виде отдельного файла: <a href="3.Modeling.png">3.Modeling.png</a>

Мы использовали набор данных [Metro Interstate Traffic Volume](https://archive.ics.uci.edu/dataset/492/metro+interstate+traffic+volume).

Ссылки на использованные модели:
- [amazon/chronos-t5-small](https://huggingface.co/amazon/chronos-t5-small)
- [amazon/chronos-bolt-base](https://huggingface.co/amazon/chronos-bolt-base)

