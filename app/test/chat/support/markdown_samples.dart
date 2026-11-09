// Markdown a model really writes, one sample per construct, shared by the
// rendering tests and the goldens.

/// A real LaTeX reply (inline maths, a currency sentence that
/// must stay prose, and a multi-line display block).
const mathReply = r'''
The mass-energy equation $E = mc^2$ written inline, and fraction $\frac{a+b}{c}$ too.

- Summation: $\sum_{i=1}^{n} i = \frac{n(n+1)}{2}$
- Gaussian integral: $\int_0^\infty e^{-x^2}\,dx = \frac{\sqrt{\pi}}{2}$
- Greek letters: $\alpha\beta\gamma \to \infty$

Inverse of a 2x2 matrix:

$$
\begin{pmatrix} a & b \\ c & d \end{pmatrix}^{-1} = \frac{1}{ad-bc}\begin{pmatrix} d & -b \\ -c & a \end{pmatrix}
$$

Parentheses notation works as well: \(x^2 + y^2 = r^2\), and

\[
\oint_C \mathbf{F}\cdot d\mathbf{r} = \iint_S (\nabla \times \mathbf{F}) \cdot d\mathbf{S}
\]

Lunch prices are $5 and $10, neither is a formula; `$HOME` in code is not either.''';

/// Headings, paragraphs and styled text.
const headingsReply = '''
# Heading 1
Body paragraph: DeepSeek Harness (DSH) brings models, tools, and workspaces together, with **bold**, *italic*, ~~strikethrough~~, and `inline code` mixed without jumping line height.

## Heading 2
English and typography mixed formatting, quotes "like this", (parentheses), and dashes---should not be cramped.

### Heading 3
#### Heading 4
##### Heading 5
###### Heading 6
Final paragraph.''';

/// Lists: nested, ordered, task lists.
const listsReply = '''
1. Step 1: Install dependencies
2. Step 2: Run tests
   - Unit tests
   - Component tests
     1. Light mode
     2. Dark mode
3. Step 3: Commit changes

- An unordered item: when text is sufficiently long to wrap onto a second line, it should align with the text rather than the bullet
- [ ] Todo: Clean up data
- [x] Done: Fix deployed

9. Step 9
10. Step 10: Two-digit numbers display completely
11. Step 11''';

/// Blockquotes and GitHub alerts.
const quotesReply = '''
> A quoted paragraph.
>
> > Nested quote.

> [!NOTE]
> This is an informative note.

> [!TIP]
> Use `flutter test --update-goldens` to regenerate test screenshots.

> [!IMPORTANT]
> Run the full test suite before releasing.

> [!WARNING]
> This operation will overwrite local changes.

> [!CAUTION]
> Cannot be undone once deleted.''';

/// A table with alignment and inline Markdown in cells.
const tableReply = '''
| Model | Context | Price ($ / 1M tokens) | Description |
|:---|:---:|---:|---|
| DeepSeek-V4-Pro | 128K | 4.00 | **Default**, stronger reasoning |
| DeepSeek-V41-Flash | 64K | 1.00 | Faster and `cheaper` |
| Custom | — | — | See [documentation](https://example.com) |''';

/// Code: a fenced block, a diff, and a Mermaid chart.
const codeReply = '''
```dart
void main() {
  final greeting = 'Hello, DSH!'; // A very long comment used to test horizontal scrolling without stretching page width
  print(greeting);
}
```

```diff
@@ -1,3 +1,3 @@
 import 'a.dart';
-final retries = 3;
+final retries = 1;
```

```mermaid
graph TD
  A[User] --> B{DSH}
  B --> C[Model]
```''';

/// Rules, footnotes, HTML bits, "Key: value" lines, long words.
const miscReply = '''
Status: Running
Version: 1.0.0

---

Footnote reference[^1], superscript x<sup>2</sup>, subscript H<sub>2</sub>O, shortcut <kbd>Ctrl</kbd>+<kbd>C</kbd>, <u>underline</u>, <mark>highlight</mark>.<br>After a line break.

<details>
<summary>Expand details</summary>

Content folded inside the details section.

</details>

Very long link https://example.com/a/very/long/path/that/keeps/going/and/going/without/any/spaces/at/all?query=1 and super long word Pneumonoultramicroscopicsilicovolcanoconiosis should wrap. Emoji 🎉👍

[^1]: This is the footnote text.''';
