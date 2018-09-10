;打印大量的信息
SECTION header vstart=0
    program_length: dd program_end
    code_entry:     dw start ;偏移地址
                    ;段基址
                    dd section.code_1.start
    realloc_item:   dw (header_end - main_code_seg) / 4
    
    ;程序重定位表
    main_code_seg: dd section.main_code.start
    help_code_seg: dd section.help_code.start
    main_data_seg: dd section.main_data.start
    help_data_seg: dd section.help_data.start

    header_end:
SECTION main_code align=16 vstart=0
    
SECTION help_code align=16 vstart=0

SECTION main_data align=16 vstart=0

SECTION help_data align=16 vstart=0

SECTION stack aliugn=16 vstart=0
    resb 256
     stack_end:
SECTION trail align=16
    program_end: