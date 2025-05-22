// Simple C program to display "ABC" on VGA, using 0x0001500 address and the new instantiation of the character_buffer module
#define VGA_FRAMEBUFFER_BASE ((volatile unsigned char *)0x00001500)

//function that writes a character to a specific offset in the framebuffer
void vga_write_char_at_offset(int offset, char c) {
    if (offset >= 0 && offset < 64) { //6 bit addressable range
        VGA_FRAMEBUFFER_BASE[offset] = c;
    }
}

void vga_clear_first_line_accessible() {
    //clear  first 64 character positions 
    for (int i = 0; i < 64; i++) {
        VGA_FRAMEBUFFER_BASE[i] = ' '; //ASCII character for space (U+0020)
    }
}

int main() {
    //clear  portion of  screen for writing, first line
    vga_clear_first_line_accessible();

    //write A, B, C (caps) to the first three character positions on the screen
    //(column 0, row 0), (column 1, row 0), (column 2, row 0)
    //Framebuffer offsets are 0, 1, 2

    vga_write_char_at_offset(0, 'A'); //(0x41)
    vga_write_char_at_offset(1, 'B'); //(0x42)
    vga_write_char_at_offset(2, 'C'); //(0x43)

    //loop continously 
    while (1) {
        
    }

    return 0;
}
