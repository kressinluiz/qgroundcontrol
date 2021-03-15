package org.mavlink.qgroundcontrol;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.Arrays;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.io.IOException;
import java.net.SocketException;
import java.net.UnknownHostException;

import android.util.Log;

import com.shenyaocn.android.OpenH264.ByteArrayOutputStream;
import com.skydroid.fpvlibrary.utils.BusinessUtils;
import com.skydroid.fpvlibrary.socket.SocketConnection;

public class VideoClient {
    private int localPort;
    private InetAddress serverAddress;
    private int serverPort;
    //private SocketConnection mSocketConnection;
    //private SocketSky mSocketSky;
    private DatagramSocket udpSocket;

    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final byte[] H264Header = new byte[] { 0, 0, 0, 1 };

    public VideoClient(){
        try{
            //InetAddress serverAddr = InetAddress.getByName(null);
            //this.serverAddress = InetAddress.getByName("192.168.1.183");
            this.serverAddress = InetAddress.getByName("192.168.1.93");
            this.localPort = 6000;
            this.serverPort = 5600;
            this.udpSocket = new DatagramSocket();
            //this.mSocketConnection = new SocketConnection(this.localPort, this.serverAddress, this.serverPort);
            //this.mSocketSky = new SocketSky(this.mSocketConnection);
        } catch(Exception e){

       }
    }

    private final CircularByteBuffer circularByteBuffer = new CircularByteBuffer(524288);

    public void received(byte[] buffer, int off, int size) {
        //System.out.println("received!");
        //mSocketSky.sendMessage(buffer);
        //Log.d("MyApp", "h264 rcv and sent");
        this.circularByteBuffer.put(buffer, off, size);
        try {
          if (this.circularByteBuffer.available() > 2048)
            this.executor.execute(this.runnable);
        } catch (Exception exception) {}
      }

  private Runnable runnable = new Runnable() {
       private final byte[] buffer = new byte[2048];

       private final ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream();

       public void run() {
           android.os.Process.setThreadPriority(-18);
            Log.d("MyApp", "h264 rcv and sent out");
         while (VideoClient.this.circularByteBuffer.available() > this.buffer.length) {
             //System.out.println("inside inside HERE!");
             //mSocketSky.sendMessage(byte[] msg)
           int count = VideoClient.this.circularByteBuffer.get(this.buffer);
           if (count <= 4)
             return;
           try {
             this.byteArrayOutputStream.write(this.buffer, 0, count);
             byte[] buffer = this.byteArrayOutputStream.getBuf();
             int bufferCount = this.byteArrayOutputStream.getCount();
             int start = BusinessUtils.Find(buffer, bufferCount, 0, VideoClient.this.H264Header);
             while (start != -1) {
               int i = BusinessUtils.Find(buffer, bufferCount, start + VideoClient.this.H264Header.length, VideoClient.this.H264Header);
               if (i != -1) {
                 byte[] h264s = Arrays.copyOfRange(buffer, start, i);
                 //Log.d("MyApp", "h264 rcv and sent");
                 //mSocketSky.sendMessage(h264s);
                 //try{
                     //VideoClient.this.udpSocket = new DatagramSocket();
                     DatagramPacket packetSend = new DatagramPacket(h264s, h264s.length, VideoClient.this.serverAddress, VideoClient.this.serverPort);

                         //try{
                     udpSocket.send(packetSend);
                         //} catch(IOException e){
                         //    System.out.println("UDPClient send: IOException " + e);
                         //}
//                 } catch (SocketException e){
//                     System.out.println("UDP Client: SocketException " + e);
//                 } catch (SecurityException e) {
//                     System.out.println("UDP Client: SecurityException " + e);
//                 } catch (UnknownHostException e) {
//                     System.out.println("UDP Client: UnknownHostException " + e);
//                 }
                 //FPVVideoClient.this.decodeH264(h264s, h264s.length);
               }
               start = i;
             }
             int end = BusinessUtils.FindR(buffer, bufferCount, VideoClient.this.H264Header);
             byte[] remainBuf = this.byteArrayOutputStream.toByteArray();
             this.byteArrayOutputStream.reset();
             this.byteArrayOutputStream.write(remainBuf, end, remainBuf.length - end);
           } catch (Exception exception) {Log.d("MyApp", "exception!!!");}
           finally{
                //udpSocket.close();
           }
         }
       }
     };
}
