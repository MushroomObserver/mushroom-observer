update donations set amount=1, who='user', email='bogus@email.com';
update users set password='ae98587c6f1599fbdcc800e66db6874a8fa0e713', email='bogus@email.com';
delete from queued_email_integers;
delete from queued_email_notes;
delete from queued_email_strings;
delete from queued_emails;
delete from queries;
