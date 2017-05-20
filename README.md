# kbd-indicator.el

This is an Ubuntu-specific way to solve an Ubuntu-specific problem: When you
switch languages to ones that don't use Latin letters, or otherwise have a
radically different layout, keyboard shortcuts stop
working. See [related Ubuntu bug][bug] -- which was supposedly fixed, but keeps
reemerging anyway.

Generally, in Emacs, you want to use the internal input method anyway, but
then you have to remember to never switch the input language in Emacs, and
have a separate keystroke to switch it inside Emacs, which is a pain.

This dirty hack alleviates this pain, by reaching across Dbus into Ubuntu's
keyboard-indicator applet and registering to listen to language change events.
Upon receiving a language change event with the Emacs window active, it will
reset the language to language id 0 *(which is presumed to be English -- so
that keyboard shortcuts will keep working)* and toggle the Emacs input method
instead.

This permits you to use Emacs' internal input method while switching it with
the same language switch key that you use everywhere else, and have a
per-buffer (rather than per-application) current input language.

I don't currently have a clue how to handle more than one non-English language
correctly, nor did I extensively test it in any way.

## In Russian

Баг в результате которого в Ubuntu шорткаты перестают в работать в русской
раскладке [широко известен.][bug] С ним периодически борются, воз и ныне там,
но в случае Emacs лучше пользоваться внутренними методами ввода, а системный
переключатель вообще не трогать.

Однако как его не трогать, когда привычка вырабатывается.

Предлагаемый хитрый Ubuntu-специфический трюк позволяет не вырабатывать новую
привычку: Этот пакет садится на Dbus и слушает сообщения keyboard-indicator о
переключении языка. При получении их, он сбрасывает язык обратно на английский
*(подразумевая что он имеет language id 0, то есть стоит в списке первым)* и
выполняет переключение языка уже в Emacs.

В результате мы имеем отдельный язык для каждого буфера, переключаем язык той
же комбинацией клавиш что и во всех остальных программах, и все шорткаты
работают как обычно.

Что делать в случае более чем одного не-английского языка -- ума не приложу,
насколько все это стабильно работает тоже пока не знаю.

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
