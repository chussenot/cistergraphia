cistergraphia
=============

About
-----

...an old index full of mystery that the cistercian monks used to make 
an inventory of their library serves as a pretext for an encryption game. 
Many ideas are behind it, such as the way the Easter Island natives used to write... snail-shaped.

![monk](monk.png)

Usage
-----

So you want to Cipher your message with some techniques to a number sequence
and then use the cistercian numbers and a nice snail placement.

To use this cipher, you just have to run `./cipher` ruby script.

```
# chussenot in ~/misc/cistergraphia on git:master ✔
$ ./cister
What is your message? La navire est proche du point de rendez-vous
-> Le navire est proche du point de rendez-vous

# chussenot in ~/misc/cistergraphia on git:master ✔
$ cat tmp/inline.svg
<?xml version="1.0" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg width="10000" height="100" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
<line x1="50" y1="0" x2="50" y2="100" style="stro
....

```

![chars](chars-square.png)

Dependencies
------------

* ruby
* a svg gem.

References
==========

- [cistercian numbers](https://glossographia.wordpress.com/2013/07/09/cistercian-number-magic-of-the-boy-scouts/)
- [the ciphers of the monks](https://en.wikipedia.org/wiki/The_Ciphers_of_the_Monks)
- [King Ciphers](http://akira.ruc.dk/~jensh/Publications/2002%7bR%7d21_King_Ciphers.PDF)
- [cistercian-numerals-ciphers-of-monks](http://luxoccultapress.blogspot.fr/2013/01/cistercian-numerals-ciphers-of-monks.html)
- [create a stacked cipher](https://www.wikihow.com/Create-a-Stacked-Cipher)
