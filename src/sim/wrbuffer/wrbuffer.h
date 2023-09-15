class WrBuffer {
		WrBuffer(void);
		~WrBuffer(void);
	bool	write(uint32_t, uint16_t, uint8_t);

private:
	uint32_t*	adr;
	uint16_t*	dat;
};
