CXXFLAGS =	-O2 -g -Wall -fmessage-length=0

OBJS =		main.o textmode.o cache.o

LIBS =

TARGET =	cache

$(TARGET):	$(OBJS)
	$(CXX) -o $(TARGET) $(OBJS) $(LIBS)

all:	$(TARGET)

clean:
	rm -f $(OBJS) $(TARGET)
