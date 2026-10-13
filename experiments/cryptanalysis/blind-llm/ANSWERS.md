# Answers

The plaintexts behind [`corpus/`](corpus/), revealed after the experiment. The attacker's
recovery (upper case, from [REPORT.md](REPORT.md)) matched all 10 exactly.

| File | Plaintext |
|---|---|
| msg01.svg | burn this message |
| msg02.svg | do not trust the cellarer |
| msg03.svg | meet me at the old abbey after vespers |
| msg04.svg | brother anselm suspects nothing |
| msg05.svg | the library key is hidden under the third stone |
| msg06.svg | we found the lost gospel in the scriptorium wall |
| msg07.svg | quiet now the prior is listening |
| msg08.svg | le manuscrit est dans la crypte |
| msg09.svg | the abbot will travel north at dawn with two monks and a mule |
| msg10.svg | send the copy to clairvaux before winter |

Check them yourself: `./cistergraphia -d experiments/cryptanalysis/blind-llm/corpus/msg01.svg`
