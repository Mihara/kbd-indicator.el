# kbd-indicator.el

This is an Ubuntu-specific way to solve a specific problem, which is most
commonly seen on Ubuntu: When you switch languages to ones that don't use
Latin letters, or otherwise have a radically different layout, keyboard
shortcuts stop working. See the [related Ubuntu bug][bug] -- which was
supposedly fixed, but keeps reemerging anyway.

Generally, with Emacs, even fixing the bug for good won't be enough: While a
clever system input method can guess that when you type `C-x` and have the
Russian language selected, you mean `C-x` and not `C-ч`, you might have a
keyboard combination like `C-x w`, which will come out as `C-x ц` *anyway,*
because you release the modifier key after `C-x`. It's best not to use the
system language switcher in Emacs at all.

But if you're up to that, you have to remember to never touch the requisite
key combination in Emacs, and have a separate keystroke to switch languages
while inside Emacs, which is a pain.

This dirty hack alleviates this pain, by listening to Dbus events Gnome Shell
emits when you use the system language switcher.  Upon receiving a language
change event with the Emacs window active, it will reset the language to
language id 0 *(which is presumed to be English -- so that keyboard shortcuts
will keep working)* and toggle the Emacs input method instead.

This permits you to use Emacs' internal input method while switching it with
the same language switch key that you use everywhere else, and have a
per-buffer *(rather than per-application)* current input language.

I don't currently have a clue how to handle more than one non-English language
correctly, nor did I extensively test it in any way.

This package was never tested on a Linux other than Ubuntu, but it may in fact
work with other distributions using Gnome Shell.

## In Russian

Баг в результате которого в Ubuntu шорткаты перестают в работать в русской
раскладке [широко известен.][bug] С ним периодически борются, воз и ныне там --
иногда работает, иногда нет. Иногда проблема встречается и в других
дистрибутивах.

Тем не менее, в случае Emacs, исправление этого бага не гарантирует идеального
результата: Умный input method может догадаться, что при включенной русской
раскладке, набирая `C-x` мы имеем в виду именно `C-x`, а не `C-ч`. Но для
Emacs вполне нормальна комбинация вроде `C-x w`, которая станет `C-x ц`,
потому что мы отпускаем Ctrl после первого нажатия. Системный переключатель
раскладки лучше вообще не трогать и пользоваться только внутренним.

Однако как его не трогать, когда привычка вырабатывается.

Предлагаемый хитрый Ubuntu-специфический трюк позволяет не вырабатывать новую
привычку: Этот пакет садится на Dbus и слушает сообщения Gnome Shell о
переключении языка. При получении их, он сбрасывает язык обратно на английский
*(подразумевая что он имеет language id 0, то есть стоит в списке первым)* и
выполняет переключение языка уже в Emacs.

В результате мы имеем отдельный язык для каждого буфера, переключаем язык той
же комбинацией клавиш что и во всех остальных программах, и все шорткаты
работают как обычно.

Что делать в случае более чем одного не-английского языка -- ума не приложу,
насколько все это стабильно работает тоже пока не знаю.

Пакет никогда не тестировался на дистрибутивах Linux отличных от Ubuntu, но
теоретически может работать с другими дистрибутивами использующими Gnome Shell.

## Usage

There is currently no MELPA release.

You need to get the `kbd-indicator.el` to where it needs to be to get loaded
and:

    (require 'kbd-indicator)

Enable it with Customize or with

    (add-hook 'after-init-hook 'global-kbd-dbus-indicator-mode)

You want to set up [the input method][method] in the usual way as well, or
there will be nothing to toggle:

    (setq default-input-method 'russian-computer)

[bug]: https://bugs.launchpad.net/ubuntu/+source/gnome-control-center/+bug/990957

[method]: https://www.gnu.org/software/emacs/manual/html_node/emacs/Input-Methods.html

## License

GPLv3. See [LICENSE](LICENSE)
