// Reports which master-data ids staging knows, then pushes billing masters (offerings: 71-offerings.apex).
List<Account> locs = [SELECT MANAERP__Partner_Internal_Id__c FROM Account WHERE MANAERP__Record_Type_Developer_Name__c='Location' AND MANAERP__Partner_Internal_Id__c != null];
List<String> locIds = new List<String>(); for (Account a : locs) locIds.add(a.MANAERP__Partner_Internal_Id__c);
List<String> gradeIds = new List<String>(); for (MANAERP__Grade__c g : [SELECT MANAERP__Partner_Internal_Id__c FROM MANAERP__Grade__c WHERE MANAERP__Partner_Internal_Id__c != null]) gradeIds.add(g.MANAERP__Partner_Internal_Id__c);
List<String> ayIds = new List<String>(); for (MANAERP__Academic_Year__c y : [SELECT MANAERP__Partner_Internal_Id__c FROM MANAERP__Academic_Year__c WHERE MANAERP__Partner_Internal_Id__c != null]) ayIds.add(y.MANAERP__Partner_Internal_Id__c);
Map<String,List<String>> want = new Map<String,List<String>>{'MASTER_DATA_LOCATION'=>locIds,'MASTER_DATA_GRADE'=>gradeIds,'MASTER_DATA_ACADEMIC_YEAR'=>ayIds};
for (String t : want.keySet()) {
    Map<String,String> known = MANAERP.CalloutManabieProduct.fetchManabieUuidsBasedOnPartnerInternalIds(t, want.get(t));
    List<String> missing = new List<String>();
    for (String id : want.get(t)) if (!known.containsKey(id)) missing.add(id);
    System.debug('MLOCAL|known|' + t + '|' + known.size() + '/' + want.get(t).size() + '|missing=' + missing);
}
// Billing last: syncBillingMaster enqueues a job, and any callout after an enqueue fails with "uncommitted work pending".
for (MANAERP__Billing_Master__c b : [SELECT Id FROM MANAERP__Billing_Master__c]) {
    System.debug('MLOCAL|billing|' + b.Id + '|' + MANAERP.CalloutManabieProduct.syncBillingMaster(b.Id));
}
