Id rt = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Student').getRecordTypeId();
Id grade = [SELECT Id FROM MANAERP__Grade__c WHERE MANAERP__Partner_Internal_Id__c = '__GRADE__' LIMIT 1].Id;
Id loc = [SELECT Id FROM Account WHERE MANAERP__Partner_Internal_Id__c = '__LOC__' LIMIT 1].Id;
Contact c = new Contact(FirstName='ML', LastName='Student __TS__', Email='ml-__TS__@example.com', RecordTypeId=rt,
    MANAERP__Grade__c=grade, MANAERP__Main_Location__c=loc, MANAERP__Username__c='ml__TS__');
Database.DMLOptions o = new Database.DMLOptions(); o.DuplicateRuleHeader.allowSave = true;
Database.SaveResult sr = Database.insert(c, o);
if (!sr.isSuccess()) { System.debug('MLOCAL|error|' + sr.getErrors()[0].getMessage()); return; }
// the insert trigger overwrites Username__c with a generated one that collides on staging
update new Contact(Id = c.Id, MANAERP__Username__c = 'ml__TS__');
MANAERP.ContactSyncService.requestSyncToManabie(new Set<Id>{c.Id}, 'Student');
System.debug('MLOCAL|student|' + c.Id);
