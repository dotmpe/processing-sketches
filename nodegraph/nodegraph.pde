/*
	Plots a graph for one or more named fields reported over Serial.

	Announce:
		[Node-ID] field1 ... fieldN
	Report:
		Node-ID value1 ... valueN

	Based on work by Maurice Ribble 
	http://www.glacialwanderer.com/hobbyrobotics

2014-05-24
	- Adapted to my own JeeNode inspired serial protocol. Needs some work on the
	  protocol side but plotting OK.
	- Scale is fixed to 0-1024, fine for def. Arduino. 
	- TODO: Would want to do proper scaling based on range and resolution.
	- TODO: add filewriter again
*/
		
import processing.serial.*;

// Globals
int g_winW             = 820;   // Window Width
int g_winH             = 800;   // Window Height
boolean g_enableFilter = true;  // Enables simple filter to help smooth out data.
int g_legH             = 140; // Horizontal size legend

String currentClient;

Serial g_serial;
PFont  g_font;
// draw graph with 10px margin
cGraph g_graph         = new cGraph(10, g_legH+10, g_winW-20, g_winH-g_legH-20);

ArrayList<cDataArray> graphs;
ArrayList<Client> clients;
ArrayList<String> client_ids;

int[][] colors = {
	{ 255, 0, 0 },
	{ 0, 255, 0 },
	{ 0, 0, 255 },
	{ 255, 255, 0 },
	{ 255, 0, 255 },
	{ 0, 255, 255 }
};


void reset() {
	if (g_serial != null) {
		//g_serial.stop();
		graphs.clear();
		clients.clear();
		client_ids.clear();
	} else {
		graphs = new ArrayList<cDataArray>();
		clients = new ArrayList<Client>();
		client_ids = new ArrayList<String>();
	}
}

void drawLegend() {
	if (currentClient == null) {
		return;
	}
	int indexOf = client_ids.indexOf(currentClient);
	if (indexOf == -1) {
		return;
	}
	Client client = clients.get(indexOf);
	// This draws the graph key info
	strokeWeight(1.5);
	for (int i=0; i<client.fieldnames.length; i++) {
		int[] c = colors[i];
		stroke(c[0], c[1], c[2]);
		line(20, (g_winH-g_legH+10)+(20*i), 35, (g_winH-g_legH+10)+(20*i));
	}
	for (int i=0; i<client.fieldnames.length; i++) {
		int[] c = colors[i];
		fill(c[0], c[1], c[2]);
		text(client.fieldnames[i], 40, (g_winH-g_legH+15)+(20*i));
	}
}

void setup()
{
	size(g_winW, g_winH, P2D);

	reset();

	println(Serial.list());
	g_serial = new Serial(this, Serial.list()[4], 57600, 'N', 8, 1.0);
	g_serial.bufferUntil('\n');

	//g_font = loadFont("ArialMT-20.vlw");
	//textFont(g_font, 20);

}

void draw()
{
	strokeWeight(1);
	fill(255, 255, 255);
	g_graph.drawGraphBox();

	drawLegend();

	strokeWeight(1.5);

	int[] c;
	for (int i=0; i<graphs.size(); i++) {
		c = colors[i];
		stroke(c[0], c[1], c[2]);
		g_graph.drawLine(graphs.get(i), 0, 1024);
	}
}

/** Consume strings from serial in line-based protocol */
void serialEvent (Serial myPort) {
	// get the ASCII string:
	String inString = myPort.readStringUntil('\n');

	if (inString != null) {
		// trim off any whitespace:
		inString = trim(inString);
		String[] lineparts = split(inString, ' ');
		String[] parts = new String[lineparts.length-1];
		String idpart = lineparts[0];
		System.arraycopy(lineparts, 1, parts, 0, lineparts.length - 1);
		int clientIndex = client_ids.indexOf(idpart);
		if (clientIndex != -1) {
			System.out.print(idpart+" ");
			Client client = clients.get(clientIndex);
			float[] values = client.parse(parts);
			for (int i=0; i<values.length; i++) {
				cDataArray data = graphs.get(i);
				data.addVal(values[i]);
			}
		} else {
			if (idpart.indexOf('[') == 0 && idpart.indexOf(']') ==
					idpart.length()-1) {
				// XXX only one client
				reset();
				String id = idpart.substring(1, idpart.length()-1);
				currentClient = id;
				client_ids.add(id);
				clients.add(new Client(id, parts));
				for (int i=0;i<parts.length;i++) {
					graphs.add(new cDataArray(g_winW));
				}
			} else {
				System.out.print("? ");
				System.out.println(idpart);
			}
		}
	}
}

// This class helps mangage the arrays of data I need to keep around for graphing.
class cDataArray
{
	float[] m_data;
	int m_maxSize;
	int m_startIndex = 0;
	int m_endIndex = 0;
	int m_curSize;

	cDataArray(int maxSize)
	{
		m_maxSize = maxSize;
		m_data = new float[maxSize];
	}

	void addVal(float val)
	{
		if (g_enableFilter && (m_curSize != 0))
		{
			int indx;

			if (m_endIndex == 0)
				indx = m_maxSize-1;
			else
				indx = m_endIndex - 1;

			m_data[m_endIndex] = getVal(indx)*.5 + val*.5;
		}
		else
		{
			m_data[m_endIndex] = val;
		}

		m_endIndex = (m_endIndex+1)%m_maxSize;
		if (m_curSize == m_maxSize)
		{
			m_startIndex = (m_startIndex+1)%m_maxSize;
		}
		else
		{
			m_curSize++;
		}
	}

	float getVal(int index)
	{
		return m_data[(m_startIndex+index)%m_maxSize];
	}

	int getCurSize()
	{
		return m_curSize;
	}

	int getMaxSize()
	{
		return m_maxSize;
	}
}

// This class takes the data and helps graph it
class cGraph
{
	float m_gWidth, m_gHeight;
	float m_gLeft, m_gBottom, m_gRight, m_gTop;

	cGraph(float x, float y, float w, float h)
	{
		m_gWidth     = w;
		m_gHeight    = h;
		m_gLeft      = x;
		m_gBottom    = g_winH - y;
		m_gRight     = x + w;
		m_gTop       = g_winH - y - h;
	}

	void drawGraphBox()
	{
		stroke(0, 0, 0);
		rectMode(CORNERS);
		rect(m_gLeft, m_gBottom, m_gRight, m_gTop);
	}

	void drawLine(cDataArray data, float minRange, float maxRange)
	{
		float graphMultX = m_gWidth/data.getMaxSize();
		float graphMultY = m_gHeight/(maxRange-minRange);

		for(int i=0; i<data.getCurSize()-1; ++i)
		{
			float x0 = i*graphMultX+m_gLeft;
			float y0 = m_gBottom-((data.getVal(i)-minRange)*graphMultY);
			float x1 = (i+1)*graphMultX+m_gLeft;
			float y1 = m_gBottom-((data.getVal(i+1)-minRange)*graphMultY);
			line(x0, y0, x1, y1);
		}
	}
}


class Client 
{
	String id;
	String[] fieldnames;

	Client(String id, String[] fieldnames) {
		this.id = id;
		this.fieldnames = fieldnames;
		System.out.println("New "+id);
	}

	float[] parse(String[] values) {
		System.out.print("parse");
		float[] r = new float[values.length];
		for (int i=0; i<values.length; i++) {
			r[i] = Float.parseFloat(values[i]);

			System.out.print(' ');
			System.out.print(values[i]);
		}

		System.out.println("");
		return r;
	}
}

static boolean isNumeric(String str)
{
	try
	{
		double d = Double.parseDouble(str);
	}
	catch(NumberFormatException nfe)
	{
		return false;
	}
	return true;
}
