import codecs
import unittest
from unittest.mock import Mock, patch

from ocr_service.dto.process_context import ProcessContext
from ocr_service.processor.converter import DocumentConverter
from ocr_service.settings import settings
from ocr_service.utils.utils import is_file_content_plain_text, normalise_file_name_with_ext


class TestPlainText(unittest.TestCase):
    def test_unicode_text_is_extracted_without_libreoffice(self):
        text = "Résumé café — Ελληνικά 中文 Привет 😀\nSecond line."
        payloads = [
            text.encode("utf-8"),
            text.encode("utf-8-sig"),
            codecs.BOM_UTF16_LE + text.encode("utf-16-le"),
            codecs.BOM_UTF16_BE + text.encode("utf-16-be"),
            codecs.BOM_UTF32_LE + text.encode("utf-32-le"),
            codecs.BOM_UTF32_BE + text.encode("utf-32-be"),
        ]
        for mode in ("OCR", "NO_OCR"):
            for stream in payloads:
                for original_name in ("request-id", "request-id.txt"):
                    with self.subTest(mode=mode, prefix=stream[:4], name=original_name), patch.object(
                        settings, "OCR_SERVICE_OPERATION_MODE", mode
                    ):
                        name = normalise_file_name_with_ext(original_name, stream)
                        converter = DocumentConverter(Mock(), {})
                        converter._preprocess_doc = Mock(return_value=b"")
                        ctx = ProcessContext(stream=stream, file_name=name, file_type=None)

                        converter.prepare(ctx)

                        self.assertEqual(name, "request-id.txt")
                        self.assertEqual(ctx.output_text, text)
                        self.assertEqual(ctx.metadata["content-type"], "text/plain")
                        self.assertEqual(ctx.metadata["pages"], 1)
                        self.assertNotIn("fallback_reason", ctx.metadata)
                        converter._preprocess_doc.assert_not_called()

    def test_utf8_character_across_sample_boundary_is_not_treated_as_binary(self):
        stream = ("a" * 4095 + "é" + " rest").encode("utf-8")
        self.assertTrue(is_file_content_plain_text(stream))

    def test_binary_content_is_not_mislabeled_as_text(self):
        payloads = [
            b"",
            b"\x00\x01\x02\x03",
            b"a" * 100 + b"\x00",
            b"\xff\xfe\x00",  # Truncated UTF-16.
            b"a" * 4096 + b"\xff",  # Invalid UTF-8 after the sample.
        ]
        for stream in payloads:
            with self.subTest(prefix=stream[:8], size=len(stream)):
                self.assertFalse(is_file_content_plain_text(stream))
                self.assertEqual(normalise_file_name_with_ext("request-id", stream), "request-id")

    def test_ascii_text_and_whitespace_still_work(self):
        self.assertTrue(is_file_content_plain_text(b"Normal text\twith\r\nwhitespace\f\v"))
        self.assertTrue(is_file_content_plain_text(b" \t\n"))

    def test_text_suffix_does_not_force_binary_content_through_text_extraction(self):
        converter = DocumentConverter(Mock(), {})
        converter._preprocess_doc = Mock(return_value=b"")
        stream = b"\x00\x01\x02\x03"
        ctx = ProcessContext(stream=stream, file_name="request-id.txt", file_type=None)

        converter.prepare(ctx)

        converter._preprocess_doc.assert_called_once_with(stream, file_name="request-id.txt")
        self.assertEqual(ctx.output_text, "")

    def test_text_fallback_preserves_unicode_and_strips_byte_order_mark(self):
        converter = DocumentConverter(Mock(), {})
        text = "Résumé — 中文"
        for encoding in ("utf-8-sig", "utf-16", "utf-32"):
            with self.subTest(encoding=encoding):
                self.assertEqual(converter._extract_text_fallback(text.encode(encoding)), text)


if __name__ == "__main__":
    unittest.main()
