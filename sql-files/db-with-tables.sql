create database "app-test";
create user app with password 'app';
grant all privileges on database "app-test" to app;

CREATE TABLE phonebook(phone VARCHAR(32), firstname VARCHAR(32), lastname VARCHAR(32), address VARCHAR(64));
INSERT INTO phonebook(phone, firstname, lastname, address) VALUES('+1 123 456 7890', 'John', 'Doe', 'North America');
SELECT * FROM phonebook ORDER BY lastname;
SELECT * FROM phonebook WHERE lastname = 'Doe';
UPDATE phonebook SET address = 'Sorth America', phone = '+1 123 456 7890' WHERE firstname = 'John' AND lastname = 'Doe';
DELETE FROM phonebook WHERE firstname = 'John' AND lastname = 'Doe';
