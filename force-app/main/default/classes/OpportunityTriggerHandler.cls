public with sharing class OpportunityTriggerHandler extends TriggerHandler {

    public override void beforeInsert() {
        List<Opportunity> newOpps = (List<Opportunity>) this.newList;
        for (Opportunity opp : newOpps) {
            if (opp.Type == null) {
                opp.Type = 'New Customer';
            }
        }
    }

    public override void beforeUpdate() {
        List<Opportunity> newOpps = (List<Opportunity>) this.newList;
        Set<Id> accountIds = new Set<Id>();

        for (Opportunity opp : newOpps) {
            if (opp.Amount < 5000) {
                opp.addError('Opportunity amount must be greater than 5000');
            }
            if (opp.AccountId != null) {
                accountIds.add(opp.AccountId);
            }
        }

        Map<Id, Contact> ceoContacts = new Map<Id, Contact>();
        for (Contact c : [
            SELECT Id, AccountId
            FROM Contact
            WHERE Title = 'CEO' AND AccountId IN :accountIds
        ]) {
            if (!ceoContacts.containsKey(c.AccountId)) {
                ceoContacts.put(c.AccountId, c);
            }
        }

        for (Opportunity opp : newOpps) {
            if (opp.Primary_Contact__c == null && ceoContacts.containsKey(opp.AccountId)) {
                opp.Primary_Contact__c = ceoContacts.get(opp.AccountId).Id;
            }
        }
    }

    public override void beforeDelete() {
        List<Opportunity> oldOpps = (List<Opportunity>) this.oldList;
        Set<Id> accountIds = new Set<Id>();

        for (Opportunity opp : oldOpps) {
            if (opp.IsClosed) {
                opp.addError('Cannot delete closed opportunity');
            }
            if (opp.AccountId != null) {
                accountIds.add(opp.AccountId);
            }
        }

        Map<Id, Account> accountMap = new Map<Id, Account>(
            [SELECT Id, Industry FROM Account WHERE Id IN :accountIds]
        );

        for (Opportunity opp : oldOpps) {
            Account acc = accountMap.get(opp.AccountId);
            if (acc != null && opp.StageName == 'Closed Won' && acc.Industry == 'Banking') {
                opp.addError('Cannot delete closed opportunity');
            }
        }
    }

    public override void afterInsert() {
        List<Opportunity> newOpps = (List<Opportunity>) this.newList;
        List<Task> tasksToInsert = new List<Task>();

        for (Opportunity opp : newOpps) {
            tasksToInsert.add(new Task(
                Subject = 'Call Primary Contact',
                WhatId = opp.Id,
                WhoId = opp.Primary_Contact__c,
                OwnerId = opp.OwnerId,
                ActivityDate = Date.today().addDays(3)
            ));
        }

        if (!tasksToInsert.isEmpty()) {
            insert tasksToInsert;
        }
    }

    public override void afterUpdate() {
        if (AnotherOpportunityTriggerHelper.hasAlreadyRun) return;
        AnotherOpportunityTriggerHelper.hasAlreadyRun = true;

        List<Opportunity> newOpps = (List<Opportunity>) this.newList;
        Map<Id, Opportunity> oldMap = (Map<Id, Opportunity>) this.oldMap;

        List<Opportunity> toUpdate = new List<Opportunity>();
        for (Opportunity opp : newOpps) {
            Opportunity oldOpp = oldMap.get(opp.Id);
            if (opp.StageName != null && opp.StageName != oldOpp.StageName) {
                String stageNote = '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
                String newDescription = opp.Description != null ? opp.Description : '';
                newDescription += stageNote;
                toUpdate.add(new Opportunity(Id = opp.Id, Description = newDescription));
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    public override void afterDelete() {
        List<Opportunity> oldOpps = (List<Opportunity>) this.oldList;

        Set<Id> ownerIds = new Set<Id>();
        for (Opportunity opp : oldOpps) {
            ownerIds.add(opp.OwnerId);
        }

        Map<Id, String> ownerEmails = new Map<Id, String>();
        for (User u : [
            SELECT Id, Email
            FROM User
            WHERE Id IN :ownerIds AND Email != null
        ]) {
            ownerEmails.put(u.Id, u.Email);
        }

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Opportunity opp : oldOpps) {
            String email = ownerEmails.get(opp.OwnerId);
            if (email != null) {
                Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
                msg.setToAddresses(new List<String>{ email });
                msg.setSubject('Opportunity Deleted: ' + opp.Name);
                msg.setPlainTextBody('Your Opportunity: ' + opp.Name + ' has been deleted.');
                emails.add(msg);
            }
        }

        Integer max = Math.min(10, emails.size());
        if (max > 0) {
            List<Messaging.SingleEmailMessage> limitedEmails = new List<Messaging.SingleEmailMessage>();
            for (Integer i = 0; i < max; i++) {
                limitedEmails.add(emails[i]);
            }
            Messaging.sendEmail(limitedEmails);
        }
    }

    public override void afterUndelete() {
        List<Opportunity> newOpps = (List<Opportunity>) this.newList;
        Set<Id> acctIds = new Set<Id>();

        for (Opportunity opp : newOpps) {
            if (opp.AccountId != null && opp.Primary_Contact__c == null) {
                acctIds.add(opp.AccountId);
            }
        }

        Map<Id, Contact> vpContacts = new Map<Id, Contact>();
        for (Contact c : [
            SELECT Id, AccountId
            FROM Contact
            WHERE Title = 'VP Sales' AND AccountId IN :acctIds
        ]) {
            if (!vpContacts.containsKey(c.AccountId)) {
                vpContacts.put(c.AccountId, c);
            }
        }

        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        for (Opportunity opp : newOpps) {
            if (opp.Primary_Contact__c == null && vpContacts.containsKey(opp.AccountId)) {
                oppsToUpdate.add(new Opportunity(
                    Id = opp.Id,
                    Primary_Contact__c = vpContacts.get(opp.AccountId).Id
                ));
            }
        }

        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;
        }
    }
}