# v8 final48: residual errors

Frozen evaluation, no post-result inference or gold changes. J=Japanese; E=English/preserved.

- Japanese modifier: 45e8da8: 2/12; damage 98; reversals 43 → current: 6/12; damage 85; reversals 39
- English phrase: 45e8da8: 3/12; damage 151; reversals 86 → current: 4/12; damage 133; reversals 58
- Multiple switches: 45e8da8: 6/12; damage 84; reversals 59 → current: 6/12; damage 84; reversals 60
- Pure Japanese/English: 45e8da8: 6/6; damage 0; reversals 7 → current: 6/6; damage 0; reversals 7
- TeX/code/URL: 45e8da8: 5/6; damage 0; reversals 18 → current: 5/6; damage 0; reversals 18

## Remaining failures

### v8-final-001
- Gold: `J:asayoyakushita | E:ticket | J:wokakuninshimasu`
- Actual: `J:asayoyakushitati | E:cket | J:wokakuninshimasu`

### v8-final-002
- Gold: `J:tomodachikaratodoita | E:invitation | J:wohiraitekudasai`
- Actual: `J:tomodachikara | E:todoitainvitation | J:wohiraitekudasai`

### v8-final-003
- Gold: `J:ryokoumaenitsukutta | E:itinerary | J:wokazokuniokurimashita`
- Actual: `J:ryokoumaenitsukuttaitinerarywokazokuniokurimashita`

### v8-final-006
- Gold: `J:ashitanokaigidemiseru | E:prototype | J:woyouishimashita`
- Actual: `J:ashitanokaigide | E:miserupro | J:to | E:type | J:woyouishimashita`

### v8-final-009
- Gold: `J:mitaieigawomatometa | E:watchlist | J:wokyouyuushimasu`
- Actual: `J:mitaieigawomato | E:metawatchlist | J:wokyouyuushimasu`

### v8-final-011
- Gold: `J:shucchoudetsukau | E:voucher | J:woinsatsushiteokimasu`
- Actual: `J:shucchoudetsukauvoucherwoinsatsushiteokimasu`

### v8-final-013
- Gold: `J:kuukounitsukumaeni | E:boarding pass | J:wohozonshitekudasai`
- Actual: `J:kuukounitsukumaeniboarding | E:  | J:passwohozonshitekudasai`

### v8-final-015
- Gold: `J:setsumeiwohajimerumaeni | E:screen sharing | J:woyuukounishimasu`
- Actual: `E:set | J:sumeiwohajimerumaeni | E:screen | E:  | J:sharingwoyuukounishimasu`

### v8-final-018
- Gold: `J:shigotonishuuchuushitaitokiha | E:focus mode | J:wotsukaimasu`
- Actual: `J:shigotonishuuchuushitaitokihafo | E:cus | E:  | J:modewotsukaimasu`

### v8-final-019
- Gold: `J:okurumaeni | E:file name | J:wowakariyasukushitekudasai`
- Actual: `J:okurumaeni | E:file | E:  | J:namewowakariyasukushitekudasai`

### v8-final-020
- Gold: `J:konodougano | E:background music | J:noonryouwosukoshisagemasu`
- Actual: `J:konodougano | E:background | E:  | J:musicnoonryouwosukoshisagemasu`

### v8-final-021
- Gold: `J:sakihodotodoita | E:voice message | J:womouichidokikitaidesu`
- Actual: `J:sakihodotodoitavoice | E:  | J:messagewomouichidokikitaidesu`

### v8-final-023
- Gold: `J:kaerinikaumonowo | E:shopping list | J:nitsuikashimashita`
- Actual: `J:kaerinikaumonowoshopping | E:  | J:listnitsuikashimashita`

### v8-final-024
- Gold: `J:kininattakijiwo | E:reading list | J:niireteimasu`
- Actual: `J:kininattakijiworeading | E:  | E:listniireteimasu`

### v8-final-025
- Gold: `E:Chrome | J:no | E:tab | J:wotojitekara | E:Safari | J:dehirakinaoshimashita`
- Actual: `E:Chrome | J:no | E:tabwo | J:tojitekara | E:Safari | J:dehirakinaoshimashita`

### v8-final-026
- Gold: `J:kono | E:form | J:no | E:email | J:ranni | E:address | J:wonyuuryokushitekudasai`
- Actual: `J:kono | E:form | J:no | E:emailran | J:ni | E:address | J:wonyuuryokushitekudasai`

### v8-final-027
- Gold: `J:onseiwo | E:record | J:shitekara | E:noise | J:woherashimasu`
- Actual: `J:onseiwo | E:record | J:shitekaranoisewo | E:her | J:ashimasu`

### v8-final-031
- Gold: `J:tsugino | E:slide | J:no | E:title | J:to | E:subtitle | J:woirekaemasu`
- Actual: `J:tsugin | E:osli | J:deno | E:title | J:to | E:subtitle | J:woirekaemasu`

### v8-final-034
- Gold: `J:ano | E:playlist | J:wo | E:download | J:shite | E:offline | J:dekikitaidesu`
- Actual: `J:anoplaylistwodownloadshiteofflinedekikitaidesu`

### v8-final-036
- Gold: `J:gazouwo | E:resize | J:shitekara | E:attachment | J:toshiteokurinaoshimasu`
- Actual: `J:gazouworesizeshitekara | E:attachment | J:toshiteokurinaoshimasu`

### v8-final-047
- Gold: `J:setsuzokusakiha | E:https://api.example.org/v1/items`
- Actual: `E:set | J:suzokusakiha | E:https | E:: | E:/ | E:/api.example.org/v1/items`

