// Original Code was gleamed from somewhere off the internet :<
//     This version 0.1 was written by Ben Bloom
import java.util.*;
import java.io.*;

import org.jivesoftware.smack.Chat;
import org.jivesoftware.smack.packet.Message;
import org.jivesoftware.smack.ChatManager;
import org.jivesoftware.smack.ChatManagerListener;
import org.jivesoftware.smack.ConnectionConfiguration;
import org.jivesoftware.smack.MessageListener;
import org.jivesoftware.smack.Roster;
import org.jivesoftware.smack.RosterEntry;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.XMPPException;


public class ChatClient implements MessageListener
{
	XMPPConnection connection;
	String[] cmdList = {"cmds", "status", "fire up", "cool down"};
	
	public void login(String userName, String password) throws XMPPException
	{
		ConnectionConfiguration config = new ConnectionConfiguration("talk.google.com", 5222, "gmail.com");
		config.setCompressionEnabled(true);
		config.setSASLAuthenticationEnabled(false);
		connection = new XMPPConnection(config);

		connection.connect();
		connection.login(userName, password);
		
		ChatManager chatmanager = connection.getChatManager();
		connection.getChatManager().addChatListener(new ChatManagerListener()
		  {
		    public void chatCreated(final Chat chat, final boolean createdLocally)
		    {
		      chat.addMessageListener(new ChatClient());
		    }
		  });
	}
	
	public void sendMessage(String message, String to) throws XMPPException
	{
		Chat chat = connection.getChatManager().createChat(to, this);
		chat.sendMessage(message);
	}
	
	public void displayBuddyList()
	{
		Roster roster = connection.getRoster();
		Collection<RosterEntry> entries = roster.getEntries();
		
		System.out.println("\n\n" + entries.size() + " buddy(ies):");
		for(RosterEntry r:entries)
		{
			System.out.println(r.getUser());
		}
	}

	public void disconnect()
	{
		connection.disconnect();
	}
	
	public void processMessage(Chat chat, Message message) 
	{
		System.out.println(message.getType());
		if(message.getType() == Message.Type.chat) {
	        System.out.println(chat.getParticipant() + " says: " + message.getBody());
	        Runtime curRun;
	        String finalMessageText = "";
	        
			switch (message.getBody().toLowerCase()) {
	        	case "cmds":
	        		for (String s: cmdList) {
	        			finalMessageText += s + ", ";
	        		}
	        		break;
	        		
	        	case "hi":
	        		finalMessageText = "Hi! I'm the Sr3 expt, tell me what to do or type \"cmds\" ";
	        		break;
	        		
	        	case "status":
	        		curRun = java.lang.Runtime.getRuntime();
	        		try {
	        			Process pid = curRun.exec("Z:\\Sr3\\slyFox\\SlyFox_OvenControl\\OvenStatus.bat");
	        			pid.waitFor();
	        		} catch (IOException | InterruptedException e1) {
	        			// TODO Auto-generated catch block
	        			e1.printStackTrace();
	        		}
	        		finalMessageText = updateStatus();
	        		try
	        		{
	        			BufferedReader in
	        				= new BufferedReader(new FileReader("Z:\\Sr3\\slyFox\\SlyFox_OvenControl\\matlab_output.log"));
	        			String nextLine;

	        			while ((nextLine=in.readLine()) != null )
	        				{
	        				finalMessageText += "\n" + nextLine;
	        				}
	        			in.close();
	        		} catch (IOException e1) {
	        			// TODO Auto-generated catch block
	        			e1.printStackTrace();
	        		}
						System.out.println(finalMessageText);
	        		break;
	        		
	        	case "fire up":
	        		String status = updateStatus();
	        		
	        		switch (status) {
		        		case "Heating":
		        			finalMessageText = "Already Heating up!";
		        			break;
		        		case "Cooling":
		        			finalMessageText = "I'm sorry we're cooling down.";
		        			break;
		        		default:
		        			curRun = java.lang.Runtime.getRuntime();
			        		try {
			        			Process pid = curRun.exec("Z:\\Sr3\\slyFox\\SlyFox_OvenControl\\OvenWarmUp.bat");
			        			pid.waitFor();
			        		} catch (IOException | InterruptedException e1) {
			        			// TODO Auto-generated catch block
			        			e1.printStackTrace();
			        		}
			        		finalMessageText = "Roger that! Starting the heating program.";
			        		break;
	        		}	
	        		break;
	        		
	        	case "cool down":
	        		String status1 = updateStatus();
	        		
	        		switch (status1) {
		        		case "Heating":
		        			finalMessageText = "Already Heating up!";
		        			break;
		        		case "Cooling":
		        			finalMessageText = "I'm sorry we're cooling down already.";
		        			break;
		        		default:
		        			curRun = java.lang.Runtime.getRuntime();
			        		try {
			        			Process pid = curRun.exec("Z:\\Sr3\\slyFox\\SlyFox_OvenControl\\OvenCoolDown.bat");
			        			pid.waitFor();
			        		} catch (IOException | InterruptedException e1) {
			        			// TODO Auto-generated catch block
			        			e1.printStackTrace();
			        		}
			        		finalMessageText = "Roger that! Starting the cooling program.";
			        		break;
	        		}	
	        		break;
	        }
			
    		try {
				chat.sendMessage(finalMessageText);
			} catch (XMPPException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
		}
    }
	
	public String updateStatus()
	{
		String status = null;
		try
		{
			BufferedReader in
				= new BufferedReader(new FileReader("Z:\\Sr3\\slyFox\\SlyFox_OvenControl\\matlab_status_output.log"));

			status = in.readLine();
			in.close();
		} catch (IOException e1) {
			// TODO Auto-generated catch block
			e1.printStackTrace();
		}
		return status;
	}
	
	public static void main(String args[]) throws XMPPException, IOException
	{
		// declare variables
		ChatClient c = new ChatClient();
		BufferedReader br = new BufferedReader(new InputStreamReader(System.in));
		String msg;


		// turn on the enhanced debugger
		XMPPConnection.DEBUG_ENABLED = true;


		// provide your login information here
		c.login("strontium3expt", "698gang!");

		c.displayBuddyList();
		
		System.out.println("-----");
		System.out.println("Enter your message in the console.");
		System.out.println("All messages will be sent to bbloom");
		System.out.println("-----\n");

		while( !(msg=br.readLine()).equals("bye"))
		{
			if (msg.equals("setup"))
			{
				c.sendMessage(msg, "bbloom@gmail.com");
				//c.sendMessage(msg, "saracampbellsoup@gmail.com");
				//c.sendMessage(msg, "willjaso@gmail.com");
				//c.sendMessage(msg, "travis.lee.nicholson@gmail.com");
			}
			// your buddy's gmail address goes here
			c.sendMessage(msg, "bbloom@gmail.com");
			System.out.println(msg);
			try {
				Thread.sleep(10);
			} catch (InterruptedException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
		}

		c.disconnect();
		System.exit(0);
	}
}