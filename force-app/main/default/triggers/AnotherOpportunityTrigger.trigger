/*
* AnotherOpportunityTrigger Overview

* This trigger was initially created for handling various events on the Opportunity object. It was developed by a prior developer and has since been noted to cause some issues in our org.

* IMPORTANT:
* - This trigger does not adhere to Salesforce best practices.
* - It is essential to review, understand, and refactor this trigger to ensure maintainability, performance, and prevent any inadvertent issues.

* ISSUES:
* Avoid nested for loop - 1 instance
* Avoid DML inside for loop - 1 instance
* Bulkify Your Code - 1 instance
* Avoid SOQL Query inside for loop - 2 instances
* Stop recursion - 1 instance

* RESOURCES: 
* https://www.salesforceben.com/12-salesforce-apex-best-practices/
* https://developer.salesforce.com/blogs/developer-relations/2015/01/apex-best-practices-15-apex-commandments
*/

// Part 2: Refactored AnotherOpportunityTrigger by Christine Sparkman

trigger AnotherOpportunityTrigger on Opportunity (before insert, after insert, before update, after update, before delete, after delete, after undelete) {
    // Recursion fix
    if (Trigger.isAfter && Trigger.isUpdate) {
        if (AnotherOpportunityTriggerHelper.hasAlreadyRun) return;
        AnotherOpportunityTriggerHelper.hasAlreadyRun = true;
    }

    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            // Set default Type for new Opportunities
            for (Opportunity opp : Trigger.new) {
                if (opp.Type == null) {
                    opp.Type = 'New Customer';
                }
            }        
        } else if (Trigger.isDelete) {
            // Prevent deletion of closed Opportunities
            for (Opportunity oldOpp : Trigger.old) {
                if (oldOpp.IsClosed) {
                    oldOpp.addError('Cannot delete closed opportunity');
                }
            }
        }
    }

    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            // Create a new Task for newly inserted Opportunities
            List<Task> tasksToInsert = new List<Task>();
            for (Opportunity opp : Trigger.new) {
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

        if (Trigger.isUpdate) {
            // Append Stage changes in Opportunity Description
            List<Opportunity> updatedOpps = new List<Opportunity>();
            for (Opportunity opp : Trigger.new) {
                Opportunity oldOpp = Trigger.oldMap.get(opp.Id);
                if (opp.StageName != null && opp.StageName != oldOpp.StageName) {
                    String stageNote = '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
                    String newDescription = opp.Description != null ? opp.Description : '';
                    newDescription += stageNote;
                    updatedOpps.add(new Opportunity(Id = opp.Id, Description = newDescription));
                }
            }
            if (!updatedOpps.isEmpty()) {
                update updatedOpps;
            }     
        }

    /*
    notifyOwnersOpportunityDeleted:
    - Sends an email notification to the owner of the Opportunity when it gets deleted.
    - Uses Salesforce's Messaging.SingleEmailMessage to send the email.
    */

            // Send email notifications when an Opportunity is deleted
            if (Trigger.isDelete) {
                Set<Id> ownerIds = new Set<Id>();
                for (Opportunity opp : Trigger.old) {
                    ownerIds.add(opp.OwnerId);
                }

                // Collect Owners with Valid Emails
                Map<Id, String> ownerEmails = new Map<Id, String>();
                for (User u : [
                    SELECT Id, Email
                    FROM User
                    WHERE Id IN :ownerIds AND Email != null
                ]) {
                    ownerEmails.put(u.Id, u.Email);
                }

                // Build Email Messages
                List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
                for (Opportunity opp : Trigger.old) {
                    String email = ownerEmails.get(opp.OwnerId);
                    if (email != null) {
                        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                        mail.setToAddresses(new List<String>{ email });
                        mail.setSubject('Opportunity Deleted: ' + opp.Name);
                        mail.setPlainTextBody('Your Opportunity: ' + opp.Name + ' has been deleted.');
                        mails.add(mail);
                    }
                }

                // Limit the # of Emails to Avoid Hitting Test Limits
                List<Messaging.SingleEmailMessage> limitedEmails = new List<Messaging.SingleEmailMessage>();
                Integer maxEmails = Math.min(10, mails.size());
                for (Integer i = 0; i < maxEmails; i++) {
                    limitedEmails.add(mails[i]);
                }

                if (!limitedEmails.isEmpty()) {
                    try {
                        Messaging.sendEmail(limitedEmails);
                    } catch (Exception e) {
                        System.debug('Email send failed: ' + e.getMessage());
                    }
                }
            }

    /*
    assignPrimaryContact:
    - Assigns a Primary Contact with the Title of 'VP Sales' to undeleted Opportunities.
    - Only updates the Opportunities that don't already have a Primary Contact.
    */

        // Assign the Primary Contact to undeleted Opportunities
        if (Trigger.isUndelete) {
            Set<Id> acctIds = new Set<Id>();
            for (Opportunity opp : Trigger.new) {
                if (opp.AccountId != null && opp.Primary_Contact__c == null) {
                    acctIds.add(opp.AccountId);
                }
            }

            Map<Id, Contact> vpContacts = new Map<Id, Contact>();
            for (Contact con : [
                SELECT Id, AccountId
                FROM contact
                WHERE Title = 'VP Sales' AND AccountId IN :acctIds
            ]) {
                if (!vpContacts.containsKey(con.AccountId)) {
                    vpContacts.put(con.AccountId, con);
                }
            }

            List<Opportunity> oppsToUpdate = new List<Opportunity>();
            for (Opportunity opp : Trigger.new) {
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
}