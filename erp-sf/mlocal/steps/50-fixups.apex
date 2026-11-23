// Makes the sample data usable for product-order testing today. Idempotent; each section reports a MLOCAL line.
Date today = Date.today();

// 1. academic years: sequence everywhere, exactly one current (the one covering today, else the latest)
try {
    List<MANAERP__Academic_Year__c> years = [SELECT Id, MANAERP__Sequence__c, MANAERP__Current_Academic_Year__c, MANAERP__Start_Date_Time__c, MANAERP__End_Date_Time__c FROM MANAERP__Academic_Year__c ORDER BY MANAERP__Start_Date_Time__c];
    Decimal maxSeq = 0; for (MANAERP__Academic_Year__c y : years) if (y.MANAERP__Sequence__c != null && y.MANAERP__Sequence__c > maxSeq) maxSeq = y.MANAERP__Sequence__c;
    MANAERP__Academic_Year__c chosen;
    for (MANAERP__Academic_Year__c y : years) {
        if (y.MANAERP__Sequence__c == null) { maxSeq++; y.MANAERP__Sequence__c = maxSeq; }
        if (y.MANAERP__Start_Date_Time__c != null && y.MANAERP__End_Date_Time__c != null && y.MANAERP__Start_Date_Time__c.date() <= today && y.MANAERP__End_Date_Time__c.date() >= today) chosen = y;
    }
    if (chosen == null && !years.isEmpty()) chosen = years[years.size() - 1];
    update years;
    List<MANAERP__Academic_Year__c> unset = new List<MANAERP__Academic_Year__c>();
    for (MANAERP__Academic_Year__c y : years) if (y.MANAERP__Current_Academic_Year__c && y.Id != chosen.Id) unset.add(new MANAERP__Academic_Year__c(Id = y.Id, MANAERP__Current_Academic_Year__c = false));
    if (!unset.isEmpty()) update unset;
    if (chosen != null && !chosen.MANAERP__Current_Academic_Year__c) update new MANAERP__Academic_Year__c(Id = chosen.Id, MANAERP__Current_Academic_Year__c = true);
    System.debug('MLOCAL|fix|academic-year|current=' + (chosen == null ? 'none' : chosen.Id));

    // 2. products on the current year and still available
    List<MANAERP__Product__c> prods = new List<MANAERP__Product__c>();
    for (MANAERP__Product__c p : [SELECT Id, MANAERP__Academic_Year__c, MANAERP__Available_From__c, MANAERP__Available_Until__c FROM MANAERP__Product__c]) {
        Boolean ch = false;
        if (p.MANAERP__Academic_Year__c != chosen.Id) { p.MANAERP__Academic_Year__c = chosen.Id; ch = true; }
        if (p.MANAERP__Available_Until__c == null || p.MANAERP__Available_Until__c < today.addMonths(6)) { p.MANAERP__Available_Until__c = today.addYears(1); ch = true; }
        if (p.MANAERP__Available_From__c != null && p.MANAERP__Available_From__c > today) { p.MANAERP__Available_From__c = today.addYears(-1); ch = true; }
        if (ch) prods.add(p);
    }
    if (!prods.isEmpty()) update prods;
    System.debug('MLOCAL|fix|products|updated=' + prods.size());
} catch (Exception e) { System.debug('MLOCAL|fix-error|academic-year/products|' + e.getMessage()); }

// 3. product locations: Org-level rows are not listed by the modal, move them to a Center
try {
    List<Account> centers = [SELECT Id FROM Account WHERE MANAERP__Location_Type__c = 'Center' AND MANAERP__Partner_Internal_Id__c = 'TLocation2026Local1' LIMIT 1];
    if (centers.isEmpty()) centers = [SELECT Id FROM Account WHERE MANAERP__Location_Type__c = 'Center' LIMIT 1];
    List<MANAERP__Product_Location__c> moved = new List<MANAERP__Product_Location__c>();
    for (MANAERP__Product_Location__c pl : [SELECT Id FROM MANAERP__Product_Location__c WHERE MANAERP__Account__r.MANAERP__Location_Type__c = 'Org']) { pl.MANAERP__Account__c = centers[0].Id; moved.add(pl); }
    if (!moved.isEmpty()) update moved;
    System.debug('MLOCAL|fix|product-location|moved=' + moved.size());
} catch (Exception e) { System.debug('MLOCAL|fix-error|product-location|' + e.getMessage()); }

// 4. product grades for the test grade
try {
    String gradePid = [SELECT MANAERP__Partner_Internal_Id__c FROM MANAERP__Grade__c WHERE MANAERP__Partner_Internal_Id__c = '__GRADE__' LIMIT 1].MANAERP__Partner_Internal_Id__c;
    Id gradeId = [SELECT Id FROM MANAERP__Grade__c WHERE MANAERP__Partner_Internal_Id__c = :gradePid LIMIT 1].Id;
    Set<Id> have = new Set<Id>(); for (MANAERP__Product_Grade__c g : [SELECT MANAERP__Product__c FROM MANAERP__Product_Grade__c WHERE MANAERP__Grade__c = :gradeId]) have.add(g.MANAERP__Product__c);
    List<MANAERP__Product_Grade__c> add = new List<MANAERP__Product_Grade__c>();
    for (MANAERP__Product__c p : [SELECT Id FROM MANAERP__Product__c]) if (!have.contains(p.Id)) add.add(new MANAERP__Product_Grade__c(MANAERP__Product__c = p.Id, MANAERP__Grade__c = gradeId));
    if (!add.isEmpty()) insert add;
    System.debug('MLOCAL|fix|product-grade|added=' + add.size());
} catch (Exception e) { System.debug('MLOCAL|fix-error|product-grade|' + e.getMessage()); }

// 5. billing schedule must cover today (sample data is dated in the past): shift whole months
try {
    List<MANAERP__Billing_Period__c> periods = [SELECT Id, MANAERP__Start_Date__c, MANAERP__End_Date__c FROM MANAERP__Billing_Period__c ORDER BY MANAERP__Start_Date__c];
    Boolean covers = false; for (MANAERP__Billing_Period__c b : periods) if (b.MANAERP__Start_Date__c <= today && b.MANAERP__End_Date__c >= today) covers = true;
    if (!covers && !periods.isEmpty()) {
        Date first = periods[0].MANAERP__Start_Date__c;
        Integer d = (today.year() * 12 + today.month()) - (first.year() * 12 + first.month()) - 2; // first period two months before this month
        // Shift start and end by the same d months, keeping each period's length (quarterly stays quarterly).
        // Month-end ends stay month-end (Jan 31 -> Feb 28/29). A period that started the day after the
        // previous one ended still does, so addMonths clamping on the 29th-31st cannot open a gap.
        Date prevOldEnd = null;
        Date prevNewEnd = null;
        for (MANAERP__Billing_Period__c b : periods) {
            Date s = b.MANAERP__Start_Date__c;
            Date e = b.MANAERP__End_Date__c;
            Boolean contiguous = prevOldEnd != null && s == prevOldEnd.addDays(1);
            b.MANAERP__Start_Date__c = contiguous ? prevNewEnd.addDays(1) : s.addMonths(d);
            Boolean monthEnd = e == e.toStartOfMonth().addMonths(1).addDays(-1);
            b.MANAERP__End_Date__c = monthEnd ? e.toStartOfMonth().addMonths(d + 1).addDays(-1) : e.addMonths(d);
            prevOldEnd = e;
            prevNewEnd = b.MANAERP__End_Date__c;
        }
        List<MANAERP__Billing_Ratio__c> ratios = [SELECT Id, MANAERP__Start_Date__c, MANAERP__End_Date__c FROM MANAERP__Billing_Ratio__c];
        for (MANAERP__Billing_Ratio__c r : ratios) {
            Boolean monthEnd = r.MANAERP__End_Date__c == r.MANAERP__End_Date__c.toStartOfMonth().addMonths(1).addDays(-1);
            r.MANAERP__Start_Date__c = r.MANAERP__Start_Date__c.addMonths(d);
            r.MANAERP__End_Date__c = monthEnd ? r.MANAERP__End_Date__c.toStartOfMonth().addMonths(d + 1).addDays(-1) : r.MANAERP__End_Date__c.addMonths(d);
        }
        update periods; update ratios;
        System.debug('MLOCAL|fix|billing|shifted months=' + d);
    } else System.debug('MLOCAL|fix|billing|already covers today');
} catch (Exception e) { System.debug('MLOCAL|fix-error|billing|' + e.getMessage()); }

// 6. student sync switch
try {
    MANAERP__Sync_User_To_Manabie__c s = MANAERP__Sync_User_To_Manabie__c.getOrgDefaults();
    s.MANAERP__Student__c = true; upsert s;
    System.debug('MLOCAL|fix|sync-user|student=true');
} catch (Exception e) { System.debug('MLOCAL|fix-error|sync-user|' + e.getMessage()); }
