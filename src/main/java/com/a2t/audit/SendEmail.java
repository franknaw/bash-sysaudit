package com.a2t.audit;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

import javax.mail.*;
import javax.mail.internet.InternetAddress;
import javax.mail.internet.MimeBodyPart;
import javax.mail.internet.MimeMessage;
import javax.mail.internet.MimeMultipart;

public class SendEmail {

    private Properties prop = new Properties();
    private static String propsFile;
    private static String emailText;

    private SendEmail() {
        this.getProps();
    }

    private void sendEmail() {

        Session session = Session.getInstance(prop,
                new javax.mail.Authenticator() {
                    protected PasswordAuthentication getPasswordAuthentication() {
                        return new PasswordAuthentication(prop.getProperty("a2t.email.user"),
                                prop.getProperty("a2t.email.password"));
                    }
                });

        try {
            session.setDebug(Boolean.parseBoolean(prop.getProperty("a2t.email.debug")));
            Message message = new MimeMessage(session);
            message.setFrom(new InternetAddress(prop.getProperty("a2t.email.from")));
            message.setRecipients(
                    Message.RecipientType.TO,
                    InternetAddress.parse(prop.getProperty("a2t.email.to"))
            );
            message.setSubject(prop.getProperty("a2t.email.subject"));
            MimeBodyPart mimePart = new MimeBodyPart();
            mimePart.attachFile(new File(emailText));

            Multipart multipart = new MimeMultipart();
            multipart.addBodyPart(mimePart);
            message.setContent(multipart);

            Transport.send(message);
        } catch (MessagingException | IOException e) {
            e.printStackTrace();
        }
    }

    private void getProps() {
        try (InputStream input = new FileInputStream(propsFile)) {
            this.prop.load(input);
        } catch (IOException ex) {
            ex.printStackTrace();
        }
    }

    private void printProps() {
        prop.keySet().stream()
                .map(key -> key + ": " + prop.getProperty(key.toString()))
                .forEach(System.out::println);
    }

    public static void main(String[] args) {
        if (args.length == 2) {
            propsFile = args[0];
            emailText = args[1];
            SendEmail mail = new SendEmail();
            if (emailText.equalsIgnoreCase("print")) {
                mail.printProps();
            } else {
                mail.sendEmail();
            }
        } else {
            System.out.println("Please Enter path to properties file");
            System.out.println("Please Enter Text for email");
        }
    }

}
