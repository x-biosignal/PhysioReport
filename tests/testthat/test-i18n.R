test_that("physioLabel returns localized labels with key fallback", {
  expect_equal(physioLabel("bias", "en"), "Bias")
  expect_true(nzchar(physioLabel("bias", "ja")))
  expect_false(identical(physioLabel("bias", "en"), physioLabel("bias", "ja")))
  expect_equal(physioLabel("unknown_key"), "unknown_key")
  expect_error(physioLabel("bias", "fr"))
})

test_that("labels past the first multibyte row resolve (encoding, not fileEncoding)", {
  # Regression: read.csv(fileEncoding = "UTF-8") re-encodes into the native
  # locale and, under a non-UTF-8 locale, aborts at the first Japanese cell so
  # only row 1 ('bias') survives. These keys live well past that row, so they
  # resolve only when the whole UTF-8 table loaded via encoding = "UTF-8".
  expect_equal(physioLabel("gait_speed", "en"), "Gait speed")
  expect_equal(physioLabel("sdnn", "en"), "SDNN")
  expect_equal(physioLabel("gait_speed", "ja"), "歩行速度")
  expect_true(nzchar(physioLabel("rms_amplitude", "ja")))
})
