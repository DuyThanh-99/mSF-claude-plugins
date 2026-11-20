// One batch of product offering pushes (5 per transaction: each push runs ~20 SOQL). 70-sync.bash fills __OFFSET__.
Integer okN = 0; Integer failN = 0; Integer seen = 0;
for (MANAERP__Product__c p : [SELECT Id, Name FROM MANAERP__Product__c WHERE MANAERP__Available_Until__c >= TODAY ORDER BY Id LIMIT 5 OFFSET __OFFSET__]) {
    seen++;
    try {
        String payload = (String) MANAERP.CalloutManabieProduct.getSyncProductOfferingPayload(p.Id).get('payload');
        Map<String,Object> r = MANAERP.CalloutManabieProduct.syncProductOffering(payload);
        if ((Boolean) r.get('isSuccess')) okN++; else { failN++; System.debug('MLOCAL|offering-fail|' + p.Name + '|' + String.valueOf(r.get('body')).left(200)); }
    } catch (Exception e) { failN++; System.debug('MLOCAL|offering-error|' + p.Name + '|' + e.getMessage()); }
}
System.debug('MLOCAL|offerings|seen=' + seen + '|ok=' + okN + '|fail=' + failN);
